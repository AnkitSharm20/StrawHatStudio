-- This intermediate migration switched the helper to invoker mode during validation.
-- The following migration restores SECURITY DEFINER because the RLS policy must also detect incoming blocks.
create or replace function private.is_community_member_blocked(p_member_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $function$
  select
    case when (select auth.uid()) is null or p_member_id is null then false
    else exists (
      select 1 from public.community_blocks cb
      where (cb.blocker_id=(select auth.uid()) and cb.blocked_id=p_member_id)
         or (cb.blocker_id=p_member_id and cb.blocked_id=(select auth.uid()))
    ) end;
$function$;
revoke all on function private.is_community_member_blocked(uuid) from public, anon, authenticated;
grant execute on function private.is_community_member_blocked(uuid) to anon, authenticated;
