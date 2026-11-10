create index if not exists membership_refunds_order_id_idx
  on public.membership_refunds (order_id);

drop policy if exists "Admins read audit logs" on public.admin_audit_logs;

drop policy if exists membership_orders_read_own on public.membership_orders;
drop policy if exists membership_orders_admin_read on public.membership_orders;
create policy membership_orders_read_own_or_admin
on public.membership_orders
for select
to authenticated
using (
  (select auth.uid()) = user_id
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
);

drop policy if exists membership_entitlements_read_own on public.membership_entitlements;
drop policy if exists membership_entitlements_admin_read on public.membership_entitlements;
create policy membership_entitlements_read_own_or_admin
on public.membership_entitlements
for select
to authenticated
using (
  (select auth.uid()) = user_id
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
);

drop policy if exists membership_refunds_read_own on public.membership_refunds;
drop policy if exists membership_refunds_admin_read on public.membership_refunds;
create policy membership_refunds_read_own_or_admin
on public.membership_refunds
for select
to authenticated
using (
  (select auth.uid()) = user_id
  or ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'admin'
);

create or replace function public.purchase_shop_item_atomic(p_user_id uuid, p_item_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_item public.shop_items%rowtype;
  v_balance bigint;
  v_purchase_id uuid;
  v_stock_key text;
  v_stock_text text;
  v_stock_count integer;
begin
  if p_user_id is null then
    raise exception 'Authentication required';
  end if;

  perform 1
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'User profile not found';
  end if;

  select *
  into v_item
  from public.shop_items
  where id = p_item_id
    and is_active = true
  for update;

  if not found then
    raise exception 'Shop item is unavailable';
  end if;

  if exists (
    select 1
    from public.user_entitlements
    where user_id = p_user_id
      and shop_item_id = p_item_id
  ) then
    raise exception 'You already own this item';
  end if;

  v_stock_key := null;
  if coalesce(v_item.metadata, '{}'::jsonb) ? 'stock_count' then
    v_stock_key := 'stock_count';
  elsif coalesce(v_item.metadata, '{}'::jsonb) ? 'inventory_count' then
    v_stock_key := 'inventory_count';
  end if;

  if v_stock_key is not null then
    v_stock_text := v_item.metadata ->> v_stock_key;
    if v_stock_text is null or v_stock_text !~ '^[0-9]{1,9}$' then
      raise exception 'This item has invalid inventory settings. Please contact the studio team.';
    end if;
    v_stock_count := v_stock_text::integer;
    if v_stock_count <= 0 then
      raise exception 'This item is out of stock';
    end if;
  end if;

  select coalesce(sum(amount), 0)
  into v_balance
  from public.coin_ledger
  where user_id = p_user_id;

  if v_balance < v_item.coin_price then
    raise exception 'Not enough coins';
  end if;

  insert into public.purchases (user_id, shop_item_id, price_coins, status)
  values (p_user_id, p_item_id, v_item.coin_price, 'completed')
  returning id into v_purchase_id;

  if v_item.coin_price > 0 then
    insert into public.coin_ledger (user_id, amount, reason, reference_type, reference_id)
    values (p_user_id, -v_item.coin_price, 'shop_purchase', 'purchase', v_purchase_id);
  end if;

  insert into public.user_entitlements (user_id, shop_item_id, purchase_id, metadata)
  values (p_user_id, p_item_id, v_purchase_id, v_item.metadata)
  on conflict (user_id, shop_item_id) do nothing;

  if v_stock_key is not null then
    update public.shop_items
    set metadata = jsonb_set(
      coalesce(metadata, '{}'::jsonb),
      array[v_stock_key],
      to_jsonb(v_stock_count - 1),
      true
    ),
    updated_at = now()
    where id = p_item_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'purchase_id', v_purchase_id,
    'item_name', v_item.name,
    'coins_spent', v_item.coin_price,
    'balance_after', v_balance - v_item.coin_price,
    'stock_remaining', case when v_stock_key is null then null else v_stock_count - 1 end
  );
end;
$function$;

revoke all on function public.purchase_shop_item_atomic(uuid, uuid) from public, anon, authenticated;
grant execute on function public.purchase_shop_item_atomic(uuid, uuid) to service_role;
