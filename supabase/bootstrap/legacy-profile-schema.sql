-- Legacy baseline present before the first tracked Supabase migration.
-- This file is used only by the CI clean-replay job; it is not a production migration.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_length check (
    username is null or (char_length(username) >= 3 and char_length(username) <= 24)
  )
);
alter table public.profiles enable row level security;
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile"
on public.profiles for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);
grant select on public.profiles to anon, authenticated;
grant insert, update on public.profiles to authenticated;
grant all on public.profiles to service_role;

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  theme text not null default 'dark' check (theme in ('dark','light')),
  layout jsonb not null default '{}'::jsonb,
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.user_settings enable row level security;
drop policy if exists "Users insert own settings" on public.user_settings;
create policy "Users insert own settings"
on public.user_settings for insert to authenticated
with check ((select auth.uid()) = user_id);
drop policy if exists "Users read own settings" on public.user_settings;
create policy "Users read own settings"
on public.user_settings for select to authenticated
using ((select auth.uid()) = user_id);
drop policy if exists "Users update own settings" on public.user_settings;
create policy "Users update own settings"
on public.user_settings for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
grant select, insert, update on public.user_settings to authenticated;
grant all on public.user_settings to service_role;
