create or replace function private.block_non_discord_signups(event jsonb)
returns jsonb
language plpgsql
stable
set search_path to ''
as $function$
declare
  v_provider text := coalesce(event #>> '{user,app_metadata,provider}', '');
begin
  if v_provider not in ('discord', 'email', 'google', 'github') then
    return jsonb_build_object(
      'error',
      jsonb_build_object(
        'http_code', 403,
        'message', 'This sign-in provider is not enabled for this application.'
      )
    );
  end if;

  -- Provider admission does not grant roles or admin privileges.
  -- Elevated roles continue to be assigned only through trusted app_metadata.
  return '{}'::jsonb;
end;
$function$;
