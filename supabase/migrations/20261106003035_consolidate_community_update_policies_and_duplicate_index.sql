-- Consolidate equivalent community UPDATE policies and remove one exact duplicate index.
-- The combined predicates preserve the existing author/admin capabilities.
drop policy if exists "Admins moderate community posts" on public.community_posts;
drop policy if exists "Authors update own community posts" on public.community_posts;
create policy "Authors and admins update community posts"
on public.community_posts
for update
to authenticated
using (
  author_id = (select auth.uid())
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
)
with check (
  author_id = (select auth.uid())
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
);

drop policy if exists "Admins moderate community replies" on public.community_replies;
drop policy if exists "Authors update own replies" on public.community_replies;
create policy "Authors and admins update community replies"
on public.community_replies
for update
to authenticated
using (
  author_id = (select auth.uid())
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
)
with check (
  author_id = (select auth.uid())
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
);

drop index if exists public.idx_community_follows_followed_id;
