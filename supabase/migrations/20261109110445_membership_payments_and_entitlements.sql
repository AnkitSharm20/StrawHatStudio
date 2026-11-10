-- Membership payment state is server-owned. Browser roles can only read their own records.
create table if not exists public.membership_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tier_key text not null check (tier_key in ('nakama','supernova','yonko')),
  plan_key text not null check (plan_key in ('nakama_monthly','nakama_yearly','supernova_monthly','supernova_yearly','yonko_monthly','yonko_yearly')),
  billing_period text not null check (billing_period in ('monthly','yearly')),
  amount_paise integer not null check (amount_paise > 0),
  currency text not null default 'INR' check (currency = 'INR'),
  razorpay_order_id text not null unique,
  razorpay_payment_id text unique,
  status text not null default 'created' check (status in ('created','paid','failed','partially_refunded','refunded')),
  refunded_amount_paise integer not null default 0 check (refunded_amount_paise >= 0),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.membership_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tier_key text not null check (tier_key in ('nakama','supernova','yonko')),
  plan_key text not null,
  source_order_id uuid not null unique references public.membership_orders(id) on delete restrict,
  status text not null default 'active' check (status in ('active','superseded','refunded','expired')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create table if not exists public.membership_refunds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  order_id uuid not null references public.membership_orders(id) on delete restrict,
  payment_id text not null,
  razorpay_refund_id text unique,
  idempotency_key text not null unique,
  amount_paise integer not null check (amount_paise > 0),
  status text not null default 'requested' check (status in ('requested','processed','failed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.razorpay_webhook_events (
  event_id text primary key,
  event_type text not null,
  payload_hash text not null,
  status text not null default 'received' check (status in ('received','processed','failed')),
  error_message text,
  received_at timestamptz not null default now(),
  processed_at timestamptz
);
create index if not exists membership_orders_user_created_idx on public.membership_orders(user_id, created_at desc);
create index if not exists membership_entitlements_user_status_end_idx on public.membership_entitlements(user_id, status, ends_at desc);
create index if not exists membership_refunds_user_created_idx on public.membership_refunds(user_id, created_at desc);
alter table public.membership_orders enable row level security;
alter table public.membership_entitlements enable row level security;
alter table public.membership_refunds enable row level security;
alter table public.razorpay_webhook_events enable row level security;
create policy membership_orders_read_own on public.membership_orders for select to authenticated using ((select auth.uid()) = user_id);
create policy membership_entitlements_read_own on public.membership_entitlements for select to authenticated using ((select auth.uid()) = user_id);
create policy membership_refunds_read_own on public.membership_refunds for select to authenticated using ((select auth.uid()) = user_id);
create policy membership_orders_admin_read on public.membership_orders for select to authenticated using ((select auth.jwt()->'app_metadata'->>'role') = 'admin');
create policy membership_entitlements_admin_read on public.membership_entitlements for select to authenticated using ((select auth.jwt()->'app_metadata'->>'role') = 'admin');
create policy membership_refunds_admin_read on public.membership_refunds for select to authenticated using ((select auth.jwt()->'app_metadata'->>'role') = 'admin');
revoke all on public.membership_orders, public.membership_entitlements, public.membership_refunds, public.razorpay_webhook_events from anon, authenticated;
grant select on public.membership_orders, public.membership_entitlements, public.membership_refunds to authenticated;
create or replace function public.activate_membership_from_verified_payment(p_razorpay_order_id text,p_razorpay_payment_id text,p_amount_paise integer,p_currency text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_order public.membership_orders%rowtype; v_start timestamptz; v_end timestamptz;
begin
 select * into v_order from public.membership_orders where razorpay_order_id=p_razorpay_order_id for update;
 if not found then raise exception 'Membership order not found'; end if;
 if v_order.amount_paise<>p_amount_paise or v_order.currency<>p_currency then raise exception 'Payment amount or currency does not match the order'; end if;
 if v_order.status in ('paid','partially_refunded','refunded') then
  if v_order.razorpay_payment_id=p_razorpay_payment_id then return jsonb_build_object('success',true,'already_processed',true,'order_id',v_order.id); end if;
  raise exception 'Order already has a different payment';
 end if;
 if v_order.status not in ('created','failed') then raise exception 'Order cannot be activated'; end if;
 select max(e.ends_at) into v_start from public.membership_entitlements e where e.user_id=v_order.user_id and e.tier_key=v_order.tier_key and e.status='active' and e.ends_at>now();
 v_start:=greatest(coalesce(v_start,now()),now());
 v_end:=v_start+case when v_order.billing_period='monthly' then interval '1 month' else interval '1 year' end;
 update public.membership_entitlements set status='superseded',updated_at=now() where user_id=v_order.user_id and tier_key<>v_order.tier_key and status='active' and ends_at>now();
 update public.membership_orders set status='paid',razorpay_payment_id=p_razorpay_payment_id,paid_at=coalesce(paid_at,now()),updated_at=now() where id=v_order.id;
 insert into public.membership_entitlements(user_id,tier_key,plan_key,source_order_id,starts_at,ends_at) values(v_order.user_id,v_order.tier_key,v_order.plan_key,v_order.id,v_start,v_end) on conflict(source_order_id) do nothing;
 return jsonb_build_object('success',true,'order_id',v_order.id,'tier',v_order.tier_key,'starts_at',v_start,'ends_at',v_end);
end; $$;
create or replace function public.apply_membership_refund(p_razorpay_payment_id text,p_refunded_amount_paise integer,p_payment_amount_paise integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_order public.membership_orders%rowtype;
begin
 select * into v_order from public.membership_orders where razorpay_payment_id=p_razorpay_payment_id for update;
 if not found then return jsonb_build_object('success',false,'reason','membership_order_not_found'); end if;
 if p_refunded_amount_paise<0 or p_payment_amount_paise<>v_order.amount_paise then raise exception 'Refund amount does not match the payment'; end if;
 update public.membership_orders set refunded_amount_paise=greatest(refunded_amount_paise,p_refunded_amount_paise),status=case when p_refunded_amount_paise>=v_order.amount_paise then 'refunded' when p_refunded_amount_paise>0 then 'partially_refunded' else status end,updated_at=now() where id=v_order.id;
 if p_refunded_amount_paise>=v_order.amount_paise then update public.membership_entitlements set status='refunded',updated_at=now() where source_order_id=v_order.id and status='active'; end if;
 return jsonb_build_object('success',true,'fully_refunded',p_refunded_amount_paise>=v_order.amount_paise);
end; $$;
revoke all on function public.activate_membership_from_verified_payment(text,text,integer,text) from public,anon,authenticated;
grant execute on function public.activate_membership_from_verified_payment(text,text,integer,text) to service_role;
revoke all on function public.apply_membership_refund(text,integer,integer) from public,anon,authenticated;
grant execute on function public.apply_membership_refund(text,integer,integer) to service_role;
