create or replace function public.get_public_profile_watchlist(p_username text)
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when p.is_public = true and p.show_watchlist = true then
      array(
        select jsonb_array_elements_text(coalesce(s.preferences -> 'watchlist', '[]'::jsonb))
      )
    else array[]::text[]
  end
  from public.profiles p
  left join public.user_settings s on s.user_id = p.id
  where lower(p.username) = lower(trim(p_username))
  limit 1
$$;

revoke all on function public.get_public_profile_watchlist(text) from public;
grant execute on function public.get_public_profile_watchlist(text) to anon, authenticated;
