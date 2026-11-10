-- The signup hook only evaluates the supplied JSON payload; it needs no elevated database privileges.
create or replace function private.block_non_discord_signups(event jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  v_provider text := coalesce(event #>> '{user,app_metadata,provider}', '');
begin
  if v_provider <> 'discord' then
    return jsonb_build_object(
      'error',
      jsonb_build_object(
        'http_code', 403,
        'message', 'Only Discord sign-in is enabled for this application.'
      )
    );
  end if;
  return '{}'::jsonb;
end;
$function$;
revoke all on function private.block_non_discord_signups(jsonb) from public, anon, authenticated, supabase_auth_admin;
grant usage on schema private to supabase_auth_admin;
grant execute on function private.block_non_discord_signups(jsonb) to supabase_auth_admin;
