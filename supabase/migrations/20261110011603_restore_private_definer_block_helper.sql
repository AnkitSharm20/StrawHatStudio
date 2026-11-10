-- Restore the narrowly-scoped SECURITY DEFINER helper so RLS can detect incoming and outgoing blocks.
create or replace function private.is_community_member_blocked(p_member_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    (select auth.uid()) is not null
    and p_member_id is not null
    and exists (
      select 1 from public.community_blocks cb
      where (cb.blocker_id=(select auth.uid()) and cb.blocked_id=p_member_id)
         or (cb.blocker_id=p_member_id and cb.blocked_id=(select auth.uid()))
    );
$function$;
revoke all on function private.is_community_member_blocked(uuid) from public, anon, authenticated;
grant execute on function private.is_community_member_blocked(uuid) to anon, authenticated;
