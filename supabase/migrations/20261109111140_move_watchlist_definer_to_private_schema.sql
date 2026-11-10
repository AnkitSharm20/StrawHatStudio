-- Keep the public RPC contract, but make its exposed wrapper SECURITY INVOKER.
-- The narrowly-scoped SECURITY DEFINER implementation lives in the non-exposed private schema.
create or replace function private.get_public_profile_watchlist(p_username text)
returns text[]
language sql
stable
security definer
set search_path to ''
as $function$
  select case
    when p.is_public is true
      and p.show_watchlist is true
      and pg_catalog.jsonb_typeof(s.preferences -> 'watchlist') = 'array'
    then array(
      select pg_catalog.jsonb_array_elements_text(s.preferences -> 'watchlist')
    )
    else array[]::text[]
  end
  from public.profiles as p
  left join public.user_settings as s on s.user_id = p.id
  where pg_catalog.lower(p.username) = pg_catalog.lower(pg_catalog.btrim(p_username))
  limit 1
$function$;
revoke all on function private.get_public_profile_watchlist(text) from public;
grant usage on schema private to anon, authenticated;
grant execute on function private.get_public_profile_watchlist(text) to anon, authenticated;
create or replace function public.get_public_profile_watchlist(p_username text)
returns text[]
language sql
stable
security invoker
set search_path to ''
as $function$
  select private.get_public_profile_watchlist(p_username)
$function$;
revoke all on function public.get_public_profile_watchlist(text) from public;
grant execute on function public.get_public_profile_watchlist(text) to anon, authenticated;
