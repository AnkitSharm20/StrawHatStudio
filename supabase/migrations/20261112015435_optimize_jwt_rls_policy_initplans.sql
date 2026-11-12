-- Keep JWT claims evaluated once per statement rather than once per row.
drop policy if exists "Admins read admin audit logs" on public.admin_audit_logs;
create policy "Admins read admin audit logs"
on public.admin_audit_logs
for select
to authenticated
using (((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "Published community posts visible" on public.community_posts;
create policy "Published community posts visible"
on public.community_posts
for select
to anon, authenticated
using (
  (
    status = 'published'
    and not private.is_community_member_blocked(author_id)
  )
  or author_id = (select auth.uid())
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
);

drop policy if exists "Published replies visible" on public.community_replies;
create policy "Published replies visible"
on public.community_replies
for select
to anon, authenticated
using (
  (
    status = 'published'
    and not private.is_community_member_blocked(author_id)
  )
  or author_id = (select auth.uid())
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
);
