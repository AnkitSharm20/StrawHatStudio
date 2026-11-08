create index if not exists admin_audit_logs_actor_id_idx
  on public.admin_audit_logs (actor_id);

drop policy if exists "Admins read audit logs"
  on public.admin_audit_logs;

create policy "Admins read audit logs"
  on public.admin_audit_logs
  for select
  to authenticated
  using (((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin');
