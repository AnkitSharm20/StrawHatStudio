-- Restrict Anime Moments media to published posts, their creators, and admins.
-- Private buckets enforce storage.objects RLS for downloads and signed URL creation.
update storage.buckets
set public = false
where id = 'anime-moments';

drop policy if exists "Anime moment media visible to published creators and admins" on storage.objects;

create policy "Anime moment media visible to published creators and admins"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'anime-moments'
  and exists (
    select 1
    from public.anime_moments m
    where m.media_path = objects.name
      and (
        m.status = 'published'
        or m.creator_id = (select auth.uid())
        or (select auth.jwt()) -> 'app_metadata' ->> 'role' = 'admin'
      )
  )
);
