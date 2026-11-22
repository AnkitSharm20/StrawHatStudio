-- Enforce per-account write limits for community posts, replies, and reports.
-- This protects direct Supabase client writes, not just UI buttons.
CREATE TABLE IF NOT EXISTS private.community_write_rate_limits (
  user_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('post','reply','report')),
  window_started_at timestamptz NOT NULL,
  request_count integer NOT NULL DEFAULT 0 CHECK (request_count >= 0),
  PRIMARY KEY (user_id, action)
);

ALTER TABLE private.community_write_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.community_write_rate_limits FROM PUBLIC, anon, authenticated, service_role;

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
    v_action := 'post';
    v_limit := 5;
    v_window_seconds := 600;
  ELSIF TG_TABLE_NAME = 'community_replies' THEN
    v_action := 'reply';
    v_limit := 20;
    v_window_seconds := 600;
  ELSIF TG_TABLE_NAME = 'community_reports' THEN
    v_action := 'report';
    v_limit := 5;
    v_window_seconds := 3600;
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
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'Community rate limit reached',
      HINT = 'Please wait before trying this action again.';
  END IF;

  IF pg_catalog.mod(pg_catalog.txid_current(), 1000) = 0 THEN
    DELETE FROM private.community_write_rate_limits
    WHERE window_started_at < v_now - interval '30 days';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.enforce_community_write_rate_limit() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS community_posts_write_rate_limit ON public.community_posts;
CREATE TRIGGER community_posts_write_rate_limit
BEFORE INSERT ON public.community_posts
FOR EACH ROW EXECUTE FUNCTION private.enforce_community_write_rate_limit();

DROP TRIGGER IF EXISTS community_replies_write_rate_limit ON public.community_replies;
CREATE TRIGGER community_replies_write_rate_limit
BEFORE INSERT ON public.community_replies
FOR EACH ROW EXECUTE FUNCTION private.enforce_community_write_rate_limit();

DROP TRIGGER IF EXISTS community_reports_write_rate_limit ON public.community_reports;
CREATE TRIGGER community_reports_write_rate_limit
BEFORE INSERT ON public.community_reports
FOR EACH ROW EXECUTE FUNCTION private.enforce_community_write_rate_limit();
