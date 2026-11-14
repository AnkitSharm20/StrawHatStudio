-- Keep the privileged reward implementation outside the exposed PostgREST schema.
-- The public RPC is SECURITY INVOKER and delegates to a private SECURITY DEFINER function.
create or replace function private.claim_daily_coin_reward()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_claim public.daily_coin_claims%rowtype;
  v_ledger_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sign in to claim your daily reward.';
  end if;

  insert into public.daily_coin_claims(user_id, reward_date, amount)
  values (v_user_id, (timezone('utc', now()))::date, 10)
  on conflict (user_id, reward_date) do nothing
  returning * into v_claim;

  if v_claim.id is null then
    return jsonb_build_object(
      'success', false,
      'already_claimed', true,
      'reward_date', (timezone('utc', now()))::date
    );
  end if;

  insert into public.coin_ledger(user_id, amount, reason, reference_type, reference_id)
  values (v_user_id, v_claim.amount, 'daily_check_in', 'daily_coin_claim', v_claim.id)
  returning id into v_ledger_id;

  return jsonb_build_object(
    'success', true,
    'already_claimed', false,
    'amount', v_claim.amount,
    'reward_date', v_claim.reward_date,
    'ledger_id', v_ledger_id
  );
end;
$function$;

revoke all on function private.claim_daily_coin_reward() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.claim_daily_coin_reward() to authenticated;

create or replace function public.claim_daily_coin_reward()
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
  select private.claim_daily_coin_reward();
$function$;

revoke all on function public.claim_daily_coin_reward() from public, anon;
grant execute on function public.claim_daily_coin_reward() to authenticated;
