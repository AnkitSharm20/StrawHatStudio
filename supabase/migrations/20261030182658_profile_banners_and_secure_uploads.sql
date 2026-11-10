-- Initial profile banner storage setup. Later migrations tighten public visibility
-- and introduce the separate profile-banners-private bucket.
alter table public.profiles add column if not exists banner_url text;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-banners','profile-banners',true,10485760,array['image/jpeg','image/png','image/webp','image/gif']::text[])
on conflict(id) do update set
  public=excluded.public,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "Profile banners public read" on storage.objects;
create policy "Profile banners public read"
on storage.objects for select to anon,authenticated
using(bucket_id='profile-banners');

drop policy if exists "Users upload own profile banners" on storage.objects;
create policy "Users upload own profile banners"
on storage.objects for insert to authenticated
with check(bucket_id='profile-banners' and (storage.foldername(name))[1]=(select auth.uid())::text);

drop policy if exists "Users update own profile banners" on storage.objects;
create policy "Users update own profile banners"
on storage.objects for update to authenticated
using(bucket_id='profile-banners' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check(bucket_id='profile-banners' and (storage.foldername(name))[1]=(select auth.uid())::text);

drop policy if exists "Users delete own profile banners" on storage.objects;
create policy "Users delete own profile banners"
on storage.objects for delete to authenticated
using(bucket_id='profile-banners' and (storage.foldername(name))[1]=(select auth.uid())::text);
