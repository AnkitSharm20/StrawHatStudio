-- Enforce block relationships server-side while keeping the block table private.
-- The private boolean helper exposes no block rows or other member identifiers.
create or replace function private.is_community_member_blocked(p_member_id uuid)
returns boolean language sql stable security definer set search_path = '' as $function$
  select (select auth.uid()) is not null and p_member_id is not null and exists (
    select 1 from public.community_blocks cb
    where (cb.blocker_id=(select auth.uid()) and cb.blocked_id=p_member_id)
       or (cb.blocker_id=p_member_id and cb.blocked_id=(select auth.uid()))
  );
$function$;
revoke all on function private.is_community_member_blocked(uuid) from public,anon,authenticated;
grant execute on function private.is_community_member_blocked(uuid) to anon,authenticated;
drop policy if exists "Published community posts visible" on public.community_posts;
create policy "Published community posts visible" on public.community_posts for select to anon,authenticated
using ((status='published' and not private.is_community_member_blocked(author_id)) or author_id=(select auth.uid()) or (select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Published replies visible" on public.community_replies;
create policy "Published replies visible" on public.community_replies for select to anon,authenticated
using ((status='published' and not private.is_community_member_blocked(author_id)) or author_id=(select auth.uid()) or (select auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "Follow relationships visible" on public.community_follows;
create policy "Follow relationships visible" on public.community_follows for select to anon,authenticated
using (not private.is_community_member_blocked(follower_id) and not private.is_community_member_blocked(followed_id));
drop policy if exists "Post reactions visible" on public.community_post_reactions;
create policy "Post reactions visible" on public.community_post_reactions for select to anon,authenticated
using (not private.is_community_member_blocked(user_id));
drop policy if exists "Members follow as self" on public.community_follows;
create policy "Members follow as self" on public.community_follows for insert to authenticated
with check (follower_id=(select auth.uid()) and not private.is_community_member_blocked(followed_id));
create or replace function private.notify_community_reply()
returns trigger language plpgsql security definer set search_path = '' as $function$
declare v_owner uuid; v_community_notifications boolean:=true; v_reply_notifications boolean:=true;
begin
 if auth.uid() is null or auth.uid()<>new.author_id then raise exception 'Authenticated author context required'; end if;
 select author_id into v_owner from public.community_posts where id=new.post_id;
 if v_owner is not null and v_owner<>new.author_id and not private.is_community_member_blocked(v_owner) then
  select (preferences->'communityNotifications' is distinct from 'false'::jsonb),
         (preferences->'replyNotifications' is distinct from 'false'::jsonb)
    into v_community_notifications,v_reply_notifications from public.user_settings where user_id=v_owner;
  if not found then v_community_notifications:=true; v_reply_notifications:=true; end if;
  if v_community_notifications and v_reply_notifications then
   insert into public.studio_notifications(recipient_id,actor_id,kind,entity_type,entity_id,message)
   values(v_owner,new.author_id,'reply','post',new.post_id,'Someone replied to your post.');
  end if;
 end if;
 return new;
end; $function$;
create or replace function private.notify_community_follow()
returns trigger language plpgsql security definer set search_path = '' as $function$
declare v_community_notifications boolean:=true;
begin
 if auth.uid() is null or auth.uid()<>new.follower_id then raise exception 'Authenticated follower context required'; end if;
 if new.follower_id=new.followed_id or private.is_community_member_blocked(new.followed_id) then return new; end if;
 select (preferences->'communityNotifications' is distinct from 'false'::jsonb)
 into v_community_notifications from public.user_settings where user_id=new.followed_id;
 if not found then v_community_notifications:=true; end if;
 if v_community_notifications then
  insert into public.studio_notifications(recipient_id,actor_id,kind,entity_type,entity_id,message)
  values(new.followed_id,new.follower_id,'follow','profile',new.follower_id,'Someone followed your profile.');
 end if;
 return new;
end; $function$;
revoke all on function private.notify_community_reply() from public,anon,authenticated;
revoke all on function private.notify_community_follow() from public,anon,authenticated;
grant execute on function private.notify_community_reply() to postgres;
grant execute on function private.notify_community_follow() to postgres;
