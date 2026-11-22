-- All rate-limit triggers are BEFORE INSERT triggers and therefore return NEW.
CREATE OR REPLACE FUNCTION private.enforce_community_write_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := (SELECT auth.uid());
  v_action text;
  v_limit integer;
  v_window_seconds integer;
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_started timestamptz;
  v_count integer;
BEGIN
  IF ((SELECT auth.jwt()) ->> 'role') = 'service_role' THEN
    RETURN NEW;
  END IF;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Sign in is required for community writes';
  END IF;
  IF TG_TABLE_NAME = 'community_posts' THEN
    v_action := 'post'; v_limit := 5; v_window_seconds := 600;
  ELSIF TG_TABLE_NAME = 'community_replies' THEN
    v_action := 'reply'; v_limit := 20; v_window_seconds := 600;
  ELSIF TG_TABLE_NAME = 'community_reports' THEN
    v_action := 'report'; v_limit := 5; v_window_seconds := 3600;
  ELSIF TG_TABLE_NAME = 'community_post_reactions' THEN
    v_action := 'reaction'; v_limit := 60; v_window_seconds := 600;
  ELSIF TG_TABLE_NAME = 'community_follows' THEN
    v_action := 'follow'; v_limit := 30; v_window_seconds := 3600;
  ELSIF TG_TABLE_NAME = 'community_blocks' THEN
    v_action := 'block'; v_limit := 30; v_window_seconds := 3600;
  ELSE
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Unsupported community write target';
  END IF;
  INSERT INTO private.community_write_rate_limits AS current_window
    (user_id, action, window_started_at, request_count)
  VALUES (v_user_id, v_action, v_now, 1)
  ON CONFLICT (user_id, action) DO UPDATE
  SET
    window_started_at = CASE
      WHEN current_window.window_started_at + pg_catalog.make_interval(secs => v_window_seconds) <= v_now
      THEN v_now ELSE current_window.window_started_at END,
    request_count = CASE
      WHEN current_window.window_started_at + pg_catalog.make_interval(secs => v_window_seconds) <= v_now
      THEN 1 ELSE current_window.request_count + 1 END
  RETURNING window_started_at, request_count INTO v_started, v_count;
  IF v_count > v_limit THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'Community rate limit reached',
      HINT = 'Please wait before trying this action again.';
  END IF;
  IF pg_catalog.mod(pg_catalog.txid_current(), 1000) = 0 THEN
    DELETE FROM private.community_write_rate_limits
    WHERE window_started_at < v_now - interval '30 days';
  END IF;
  RETURN NEW;
END;
$function$;
