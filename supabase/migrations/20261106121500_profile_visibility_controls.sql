alter table public.profiles add column if not exists is_public boolean not null default true, add column if not exists show_watchlist boolean not null default true;
drop policy if exists "Public can view profiles" on public.profiles;
create policy "Public can view public profiles or own profile" on public.profiles for select to anon, authenticated using (is_public = true or id = (select auth.uid()));
