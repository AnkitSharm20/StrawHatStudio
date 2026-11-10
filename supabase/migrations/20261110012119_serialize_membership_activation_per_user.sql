-- Serialize membership activation per member to prevent overlapping tiers
-- from simultaneous captured-payment callbacks.
create or replace function public.activate_membership_from_verified_payment(
  p_razorpay_order_id text,
  p_razorpay_payment_id text,
  p_amount_paise integer,
  p_currency text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.membership_orders%rowtype;
  v_start timestamptz;
  v_end timestamptz;
  v_other_tier text;
begin
  select * into v_order from public.membership_orders
  where razorpay_order_id=p_razorpay_order_id for update;
  if not found then raise exception 'Membership order not found'; end if;
  if v_order.amount_paise<>p_amount_paise or v_order.currency<>p_currency then
    raise exception 'Payment amount or currency does not match the order';
  end if;
  if v_order.status in ('paid','partially_refunded','refunded') then
    if v_order.razorpay_payment_id=p_razorpay_payment_id then
      return jsonb_build_object('success',true,'already_processed',true,'order_id',v_order.id);
    end if;
    raise exception 'Order already has a different payment';
  end if;
  if v_order.status not in ('created','failed') then raise exception 'Order cannot be activated'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_order.user_id::text,0));

  select e.tier_key into v_other_tier from public.membership_entitlements e
  where e.user_id=v_order.user_id and e.tier_key<>v_order.tier_key
    and e.status='active' and e.ends_at>now()
  order by e.ends_at desc limit 1 for update;
  if v_other_tier is not null then
    raise exception 'An active membership in another tier must expire before changing tiers';
  end if;

  select max(e.ends_at) into v_start from public.membership_entitlements e
  where e.user_id=v_order.user_id and e.tier_key=v_order.tier_key
    and e.status='active' and e.ends_at>now();
  v_start:=greatest(coalesce(v_start,now()),now());
  v_end:=v_start+case when v_order.billing_period='monthly' then interval '1 month' else interval '1 year' end;

  update public.membership_orders set status='paid',razorpay_payment_id=p_razorpay_payment_id,
    paid_at=coalesce(paid_at,now()),updated_at=now() where id=v_order.id;
  insert into public.membership_entitlements(user_id,tier_key,plan_key,source_order_id,starts_at,ends_at)
  values(v_order.user_id,v_order.tier_key,v_order.plan_key,v_order.id,v_start,v_end)
  on conflict(source_order_id) do nothing;
  return jsonb_build_object('success',true,'order_id',v_order.id,'tier',v_order.tier_key,'starts_at',v_start,'ends_at',v_end);
end;
$$;
revoke all on function public.activate_membership_from_verified_payment(text,text,integer,text) from public,anon,authenticated;
grant execute on function public.activate_membership_from_verified_payment(text,text,integer,text) to service_role;
