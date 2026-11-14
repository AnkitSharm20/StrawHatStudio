-- Straw Hat Studio 3.0: moderated, mobile-first Anime Moments foundation.
create table public.anime_moments (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references auth.users(id) on delete cascade,
  caption text not null default '' check (char_length(caption) <= 500),
  media_path text not null unique,
  media_type text not null check (media_type in ('image','video')),
  status text not null default 'pending' check (status in ('pending','published','hidden','removed')),
  aspect_ratio numeric(7,4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  constraint anime_moments_ratio_positive check (aspect_ratio is null or aspect_ratio > 0)
);

create index anime_moments_feed_idx on public.anime_moments (published_at desc, created_at desc) where status = 'published';
create index anime_moments_creator_idx on public.anime_moments (creator_id, created_at desc);

alter table public.anime_moments enable row level security;
grant select on public.anime_moments to anon, authenticated;
grant insert, update, delete on public.anime_moments to authenticated;

create policy "Published anime moments are visible"
on public.anime_moments for select to anon, authenticated
using (
  status = 'published'
  or creator_id = (select auth.uid())
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
);

create policy "Members submit their own pending anime moments"
on public.anime_moments for insert to authenticated
with check (creator_id = (select auth.uid()) and status = 'pending');

create policy "Creators edit pending moments and admins moderate"
on public.anime_moments for update to authenticated
using (
  (creator_id = (select auth.uid()) and status = 'pending')
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
)
with check (
  (creator_id = (select auth.uid()) and status = 'pending')
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
);

create policy "Creators remove pending moments and admins moderate"
on public.anime_moments for delete to authenticated
using (
  (creator_id = (select auth.uid()) and status = 'pending')
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
);

create table public.anime_moment_reactions (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.anime_moments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (moment_id, user_id)
);

create index anime_moment_reactions_moment_idx on public.anime_moment_reactions (moment_id);
alter table public.anime_moment_reactions enable row level security;
grant select on public.anime_moment_reactions to anon, authenticated;
grant insert, delete on public.anime_moment_reactions to authenticated;

create policy "Reactions on published moments are visible"
on public.anime_moment_reactions for select to anon, authenticated
using (
  exists (
    select 1 from public.anime_moments m
    where m.id = moment_id and m.status = 'published'
  )
  or user_id = (select auth.uid())
);

create policy "Members react to published moments"
on public.anime_moment_reactions for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.anime_moments m
    where m.id = moment_id and m.status = 'published'
  )
);

create policy "Members remove their own reactions"
on public.anime_moment_reactions for delete to authenticated
using (user_id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'anime-moments',
  'anime-moments',
  true,
  20971520,
  array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "Members upload anime moment media to own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'anime-moments'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Creators delete media for pending anime moments"
on storage.objects for delete to authenticated
using (
  bucket_id = 'anime-moments'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1 from public.anime_moments m
    where m.media_path = name
      and m.creator_id = (select auth.uid())
      and m.status = 'pending'
  )
);
