-- Legacy baseline present before the first tracked Supabase migration.
-- This file is used only by the CI clean-replay job; it is not a production migration.
-- It recreates the pre-existing profile, site CMS, media, shop and paper-coin schema.

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

create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  media_type text not null check (media_type = any (array['gif','image','video','audio']::text[])),
  storage_path text not null,
  mime_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  duration_seconds numeric,
  placement jsonb not null default '{}'::jsonb,
  is_default boolean not null default false,
  is_published boolean not null default false,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists media_assets_uploaded_by_idx on public.media_assets(uploaded_by);
alter table public.media_assets enable row level security;
drop policy if exists "Published media visible" on public.media_assets;
create policy "Published media visible" on public.media_assets for select to anon,authenticated
using (is_published=true or (select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins insert media" on public.media_assets;
create policy "Admins insert media" on public.media_assets for insert to authenticated
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins update media" on public.media_assets;
create policy "Admins update media" on public.media_assets for update to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins delete media" on public.media_assets;
create policy "Admins delete media" on public.media_assets for delete to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='admin');
grant select on public.media_assets to anon;
grant select,insert,update,delete on public.media_assets to authenticated;
grant all on public.media_assets to service_role;

create table if not exists public.shop_items (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  item_type text not null check (item_type = any (array['custom_gif','theme','badge','effect','other']::text[])),
  coin_price integer not null default 0 check (coin_price >= 0),
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.shop_items enable row level security;
drop policy if exists "Active shop items visible" on public.shop_items;
create policy "Active shop items visible" on public.shop_items for select to anon,authenticated
using (is_active=true or (select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins insert shop items" on public.shop_items;
create policy "Admins insert shop items" on public.shop_items for insert to authenticated
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins update shop items" on public.shop_items;
create policy "Admins update shop items" on public.shop_items for update to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins delete shop items" on public.shop_items;
create policy "Admins delete shop items" on public.shop_items for delete to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='admin');
grant select on public.shop_items to anon;
grant select,insert,update,delete on public.shop_items to authenticated;
grant all on public.shop_items to service_role;

create table if not exists public.site_config (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.site_config enable row level security;
drop policy if exists "Public read site config" on public.site_config;
create policy "Public read site config" on public.site_config for select to anon,authenticated
using (key = any (array['brand','default_stream','theme']::text[])
  or (select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins insert site config" on public.site_config;
create policy "Admins insert site config" on public.site_config for insert to authenticated
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins update site config" on public.site_config;
create policy "Admins update site config" on public.site_config for update to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins delete site config" on public.site_config;
create policy "Admins delete site config" on public.site_config for delete to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='admin');
grant select on public.site_config to anon;
grant select,insert,update,delete on public.site_config to authenticated;
grant all on public.site_config to service_role;

create table if not exists public.ad_slots (
  id uuid primary key default gen_random_uuid(),
  slot_key text not null unique,
  label text not null,
  placement jsonb not null default '{}'::jsonb,
  creative_url text,
  destination_url text,
  is_enabled boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.ad_slots enable row level security;
drop policy if exists "Enabled ads visible" on public.ad_slots;
create policy "Enabled ads visible" on public.ad_slots for select to anon,authenticated
using (is_enabled=true or (select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins insert ads" on public.ad_slots;
create policy "Admins insert ads" on public.ad_slots for insert to authenticated
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins update ads" on public.ad_slots;
create policy "Admins update ads" on public.ad_slots for update to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Admins delete ads" on public.ad_slots;
create policy "Admins delete ads" on public.ad_slots for delete to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='admin');
grant select on public.ad_slots to anon;
grant select,insert,update,delete on public.ad_slots to authenticated;
grant all on public.ad_slots to service_role;

create table if not exists public.redeem_codes (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique,
  reward_coins integer not null check (reward_coins > 0),
  max_redemptions integer not null default 1 check (max_redemptions > 0),
  redemption_count integer not null default 0 check (redemption_count >= 0),
  expires_at timestamptz,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists redeem_codes_created_by_idx on public.redeem_codes(created_by);
alter table public.redeem_codes enable row level security;
drop policy if exists "Admins manage redeem codes" on public.redeem_codes;
create policy "Admins manage redeem codes" on public.redeem_codes for all to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
grant select on public.redeem_codes to authenticated;
grant all on public.redeem_codes to service_role;

create table if not exists public.coin_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null check (amount <> 0),
  reason text not null,
  reference_type text,
  reference_id uuid,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists coin_ledger_created_by_idx on public.coin_ledger(created_by);
create index if not exists coin_ledger_user_created_idx on public.coin_ledger(user_id,created_at desc);
alter table public.coin_ledger enable row level security;
drop policy if exists "Users read own coin ledger" on public.coin_ledger;
create policy "Users read own coin ledger" on public.coin_ledger for select to authenticated
using ((select auth.uid())=user_id or (select auth.jwt()->'app_metadata'->>'role')='admin');
grant select on public.coin_ledger to authenticated;
grant all on public.coin_ledger to service_role;

create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  shop_item_id uuid not null references public.shop_items(id),
  price_coins integer not null check (price_coins >= 0),
  status text not null default 'completed' check (status = any (array['pending','completed','refunded','failed']::text[])),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists purchases_shop_item_idx on public.purchases(shop_item_id);
create index if not exists purchases_user_created_idx on public.purchases(user_id,created_at desc);
alter table public.purchases enable row level security;
drop policy if exists "Users read own purchases" on public.purchases;
create policy "Users read own purchases" on public.purchases for select to authenticated
using ((select auth.uid())=user_id or (select auth.jwt()->'app_metadata'->>'role')='admin');
grant select on public.purchases to authenticated;
grant all on public.purchases to service_role;

create table if not exists public.redeem_redemptions (
  id uuid primary key default gen_random_uuid(),
  redeem_code_id uuid not null references public.redeem_codes(id),
  user_id uuid not null references auth.users(id) on delete cascade,
  reward_coins integer not null check (reward_coins > 0),
  redeemed_at timestamptz not null default now(),
  unique(redeem_code_id,user_id)
);
create index if not exists redeem_redemptions_user_idx on public.redeem_redemptions(user_id,redeemed_at desc);
alter table public.redeem_redemptions enable row level security;
drop policy if exists "Users read own redemptions" on public.redeem_redemptions;
create policy "Users read own redemptions" on public.redeem_redemptions for select to authenticated
using ((select auth.uid())=user_id or (select auth.jwt()->'app_metadata'->>'role')='admin');
grant select on public.redeem_redemptions to authenticated;
grant all on public.redeem_redemptions to service_role;

create table if not exists public.user_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  shop_item_id uuid not null references public.shop_items(id) on delete cascade,
  purchase_id uuid references public.purchases(id) on delete set null,
  granted_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique(user_id,shop_item_id)
);
create index if not exists user_entitlements_purchase_idx on public.user_entitlements(purchase_id);
create index if not exists user_entitlements_shop_item_idx on public.user_entitlements(shop_item_id);
alter table public.user_entitlements enable row level security;
drop policy if exists "Users read own entitlements" on public.user_entitlements;
create policy "Users read own entitlements" on public.user_entitlements for select to authenticated
using ((select auth.uid())=user_id or (select auth.jwt()->'app_metadata'->>'role')='admin');
grant select on public.user_entitlements to authenticated;
grant all on public.user_entitlements to service_role;
