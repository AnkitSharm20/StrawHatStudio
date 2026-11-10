-- Do not send reaction notifications across a block relationship.
create or replace function private.notify_community_reaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_owner uuid;
  v_community_notifications boolean := true;
begin
  if auth.uid() is null or auth.uid() <> new.user_id then
    raise exception 'Authenticated reactor context required';
  end if;

  select author_id into v_owner
  from public.community_posts
  where id = new.post_id;

  if v_owner is not null and v_owner <> new.user_id
     and not private.is_community_member_blocked(v_owner) then
    select (preferences->'communityNotifications' is distinct from 'false'::jsonb)
      into v_community_notifications
    from public.user_settings
    where user_id = v_owner;

    if not found then
      v_community_notifications := true;
    end if;

    if v_community_notifications then
      insert into public.studio_notifications(recipient_id,actor_id,kind,entity_type,entity_id,message)
      values(v_owner,new.user_id,'reaction','post',new.post_id,'Someone reacted to your post.');
    end if;
  end if;
  return new;
end;
$function$;
revoke all on function private.notify_community_reaction() from public, anon, authenticated;
grant execute on function private.notify_community_reaction() to postgres;
