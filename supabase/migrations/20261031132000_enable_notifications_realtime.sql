-- Enable Postgres Changes for the authenticated notifications inbox.
-- Row visibility remains restricted by the existing recipient-owned SELECT policy.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'studio_notifications'
  ) then
    alter publication supabase_realtime add table public.studio_notifications;
  end if;
end
$$;
