-- Community core: additive tables with per-user RLS.
-- Applied to Supabase project xlwtpysdknjzgjiecbhm.
create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(), author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 5000), image_url text,
  spoiler boolean not null default false, status text not null default 'published' check(status in ('published','hidden','removed')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists community_posts_feed_idx on public.community_posts(status,created_at desc);
create table if not exists public.community_replies (
  id uuid primary key default gen_random_uuid(), post_id uuid not null references public.community_posts(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check(char_length(btrim(body)) between 1 and 2000),
  status text not null default 'published' check(status in ('published','hidden','removed')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists community_replies_post_idx on public.community_replies(post_id,created_at asc);
create table if not exists public.community_post_reactions (
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null default 'like' check(reaction in ('like','love','laugh','fire')),
  created_at timestamptz not null default now(), primary key(post_id,user_id)
);
create table if not exists public.studio_notifications (
  id uuid primary key default gen_random_uuid(), recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  kind text not null check(kind in ('reply','reaction','follow','announcement','reward','system')),
  entity_type text, entity_id uuid, message text not null check(char_length(message) between 1 and 240),
  read_at timestamptz, created_at timestamptz not null default now()
);
create index if not exists studio_notifications_inbox_idx on public.studio_notifications(recipient_id,created_at desc);
create table if not exists public.community_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(follower_id,followed_id), check(follower_id<>followed_id)
);
create table if not exists public.community_reports (
  id uuid primary key default gen_random_uuid(), reporter_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid references public.community_posts(id) on delete cascade,
  reply_id uuid references public.community_replies(id) on delete cascade,
  reason text not null check(reason in ('spam','harassment','spoiler','copyright','other')),
  details text check(details is null or char_length(details)<=1000),
  status text not null default 'open' check(status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(), check(num_nonnulls(post_id,reply_id)=1)
);
create index if not exists community_reports_status_idx on public.community_reports(status,created_at desc);
alter table public.community_posts enable row level security;
alter table public.community_replies enable row level security;
alter table public.community_post_reactions enable row level security;
alter table public.studio_notifications enable row level security;
alter table public.community_follows enable row level security;
alter table public.community_reports enable row level security;
create policy "Published community posts visible" on public.community_posts for select to anon,authenticated using(status='published' or author_id=(select auth.uid()) or (select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "Members create own community posts" on public.community_posts for insert to authenticated with check(author_id=(select auth.uid()) and status='published');
create policy "Authors update own community posts" on public.community_posts for update to authenticated using(author_id=(select auth.uid())) with check(author_id=(select auth.uid()));
create policy "Authors delete own community posts" on public.community_posts for delete to authenticated using(author_id=(select auth.uid()));
create policy "Published replies visible" on public.community_replies for select to anon,authenticated using(status='published' or author_id=(select auth.uid()) or (select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "Members reply to published posts" on public.community_replies for insert to authenticated with check(author_id=(select auth.uid()) and status='published' and exists(select 1 from public.community_posts p where p.id=post_id and p.status='published'));
create policy "Authors update own replies" on public.community_replies for update to authenticated using(author_id=(select auth.uid())) with check(author_id=(select auth.uid()));
create policy "Authors delete own replies" on public.community_replies for delete to authenticated using(author_id=(select auth.uid()));
create policy "Post reactions visible" on public.community_post_reactions for select to anon,authenticated using(true);
create policy "Members add own reactions" on public.community_post_reactions for insert to authenticated with check(user_id=(select auth.uid()));
create policy "Members update own reactions" on public.community_post_reactions for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy "Members remove own reactions" on public.community_post_reactions for delete to authenticated using(user_id=(select auth.uid()));
create policy "Members read own notifications" on public.studio_notifications for select to authenticated using(recipient_id=(select auth.uid()));
create policy "Members mark own notifications read" on public.studio_notifications for update to authenticated using(recipient_id=(select auth.uid())) with check(recipient_id=(select auth.uid()));
create policy "Follow relationships visible" on public.community_follows for select to anon,authenticated using(true);
create policy "Members follow as self" on public.community_follows for insert to authenticated with check(follower_id=(select auth.uid()));
create policy "Members unfollow as self" on public.community_follows for delete to authenticated using(follower_id=(select auth.uid()));
create policy "Members create own reports" on public.community_reports for insert to authenticated with check(reporter_id=(select auth.uid()));
create policy "Reporters and admins read reports" on public.community_reports for select to authenticated using(reporter_id=(select auth.uid()) or (select auth.jwt()->'app_metadata'->>'role')='admin');
