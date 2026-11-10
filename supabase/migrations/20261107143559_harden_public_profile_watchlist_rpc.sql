-- Harden the public watchlist RPC: fix search_path, validate stored JSON shape, and use qualified built-ins.
create or replace function public.get_public_profile_watchlist(p_username text)
returns text[]
language sql
stable
security definer
set search_path = ''
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
revoke all on function public.get_public_profile_watchlist(text) from public;
grant execute on function public.get_public_profile_watchlist(text) to anon, authenticated;
