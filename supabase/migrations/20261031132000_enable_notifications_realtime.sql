-- Enable Postgres Changes for the authenticated notifications inbox.
-- Row visibility remains restricted by the existing recipient-owned SELECT policy.
alter publication supabase_realtime add table public.studio_notifications;
