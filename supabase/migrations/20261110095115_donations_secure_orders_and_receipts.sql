create table public.donation_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount_paise integer not null check (amount_paise between 1000 and 10000000),
  currency text not null default 'INR' check (currency = 'INR'),
  donor_display_name text not null default 'Nakama' check (char_length(btrim(donor_display_name)) between 1 and 40),
  is_anonymous boolean not null default false,
  donor_message text check (donor_message is null or char_length(donor_message) <= 250),
  receipt_number text not null unique default ('SHD-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
  razorpay_order_id text not null unique,
  razorpay_payment_id text unique,
  status text not null default 'created' check (status in ('created', 'paid', 'failed', 'partially_refunded', 'refunded')),
  refunded_amount_paise integer not null default 0 check (refunded_amount_paise >= 0 and refunded_amount_paise <= amount_paise),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index donation_orders_user_created_idx on public.donation_orders (user_id, created_at desc);
create index donation_orders_status_paid_idx on public.donation_orders (status, paid_at desc)
  where status in ('paid', 'partially_refunded');

alter table public.donation_orders enable row level security;

create policy donation_orders_read_own_or_admin
on public.donation_orders
for select
to authenticated
using (
  (select auth.uid()) = user_id
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
);

revoke all on public.donation_orders from anon, authenticated;
grant select on public.donation_orders to authenticated;
grant all on public.donation_orders to service_role;

create view public.public_donation_wall
with (security_invoker = false)
as
select
  id,
  case when is_anonymous then 'Anonymous Nakama' else donor_display_name end as donor_name,
  amount_paise,
  paid_at
from public.donation_orders
where status in ('paid', 'partially_refunded')
order by paid_at desc;

revoke all on public.public_donation_wall from anon, authenticated;
grant select on public.public_donation_wall to anon, authenticated;

comment on table public.donation_orders is
  'Server-created Razorpay donation orders. Client writes are prohibited; captured payments are confirmed by the Edge Function or signed webhook.';
comment on view public.public_donation_wall is
  'Public-safe donation wall. Exposes only donor display name (or anonymous label), amount, and paid timestamp for confirmed donations.';