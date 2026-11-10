-- This is a trigger-only SECURITY DEFINER function; it must not be callable through RPC.
revoke all on function private.notify_community_reaction() from public, anon, authenticated;
grant execute on function private.notify_community_reaction() to postgres;
