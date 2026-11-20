-- Optimize MFA-aware policies to cache JWT reads per statement and clean up
-- expired rate-limit buckets periodically.

DO $mfa$
DECLARE r record; v_predicate text := $predicate$
(NOT EXISTS (SELECT 1 FROM auth.mfa_factors AS factor WHERE factor.user_id = (SELECT auth.uid()) AND factor.status = 'verified') OR ((SELECT auth.jwt()) ->> 'aal') = 'aal2')
$predicate$;
BEGIN
  FOR r IN SELECT schemaname, tablename FROM pg_tables WHERE schemaname='public' AND rowsecurity=true LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I','mfa_required_for_enrolled_users',r.schemaname,r.tablename);
    EXECUTE format('CREATE POLICY %I ON %I.%I AS RESTRICTIVE FOR ALL TO authenticated USING (%s) WITH CHECK (%s)','mfa_required_for_enrolled_users',r.schemaname,r.tablename,v_predicate,v_predicate);
  END LOOP;
  EXECUTE 'DROP POLICY IF EXISTS mfa_required_for_enrolled_users ON storage.objects';
  EXECUTE format('CREATE POLICY %I ON storage.objects AS RESTRICTIVE FOR ALL TO authenticated USING (%s) WITH CHECK (%s)','mfa_required_for_enrolled_users',v_predicate,v_predicate);
END
$mfa$;

CREATE INDEX IF NOT EXISTS edge_rate_limits_expires_at_idx ON private.edge_rate_limits(expires_at);

CREATE OR REPLACE FUNCTION public.consume_edge_rate_limit(p_bucket_key text,p_limit integer,p_window_seconds integer)
RETURNS TABLE(allowed boolean,remaining integer,retry_after_seconds integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE v_started timestamptz; v_count integer; v_now timestamptz := clock_timestamp();
BEGIN
  IF ((SELECT auth.jwt()) ->> 'role') IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Service role required'; END IF;
  IF p_bucket_key IS NULL OR length(p_bucket_key)<32 OR length(p_bucket_key)>128 OR p_limit IS NULL OR p_limit<1 OR p_limit>1000 OR p_window_seconds IS NULL OR p_window_seconds<1 OR p_window_seconds>86400 THEN
    RAISE EXCEPTION 'Invalid rate limit parameters';
  END IF;
  IF mod(hashtextextended(p_bucket_key,0),100)=0 THEN
    DELETE FROM private.edge_rate_limits WHERE expires_at < v_now - interval '1 day';
  END IF;
  INSERT INTO private.edge_rate_limits AS current_bucket(bucket_key,window_started_at,request_count,expires_at)
  VALUES(p_bucket_key,v_now,1,v_now+make_interval(secs=>p_window_seconds))
  ON CONFLICT(bucket_key) DO UPDATE SET
    window_started_at=CASE WHEN current_bucket.window_started_at+make_interval(secs=>p_window_seconds)<=v_now THEN v_now ELSE current_bucket.window_started_at END,
    request_count=CASE WHEN current_bucket.window_started_at+make_interval(secs=>p_window_seconds)<=v_now THEN 1 ELSE least(current_bucket.request_count+1,p_limit+1) END,
    expires_at=CASE WHEN current_bucket.window_started_at+make_interval(secs=>p_window_seconds)<=v_now THEN v_now+make_interval(secs=>p_window_seconds) ELSE current_bucket.expires_at END
  RETURNING current_bucket.window_started_at,current_bucket.request_count INTO v_started,v_count;
  RETURN QUERY SELECT v_count<=p_limit, greatest(p_limit-v_count,0), greatest(ceil(extract(epoch FROM (v_started+make_interval(secs=>p_window_seconds)-v_now)))::integer,0);
END;
$function$;
