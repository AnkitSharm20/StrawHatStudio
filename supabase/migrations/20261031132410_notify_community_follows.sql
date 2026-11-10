-- Notify a followed member when someone follows them, respecting community notification preferences.
create or replace function private.notify_community_follow()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_community_notifications boolean := true;
begin
  if auth.uid() is null or auth.uid() <> new.follower_id then
    raise exception 'Authenticated follower context required';
  end if;

  if new.follower_id = new.followed_id then
    return new;
  end if;

  select (preferences->'communityNotifications' is distinct from 'false'::jsonb)
    into v_community_notifications
  from public.user_settings
  where user_id = new.followed_id;

  if not found then
    v_community_notifications := true;
  end if;

  if v_community_notifications then
    insert into public.studio_notifications(recipient_id,actor_id,kind,entity_type,entity_id,message)
    values(new.followed_id,new.follower_id,'follow','profile',new.follower_id,'Someone followed your profile.');
  end if;

  return new;
end;
$function$;

drop trigger if exists community_follow_notification on public.community_follows;
create trigger community_follow_notification
after insert on public.community_follows
for each row execute function private.notify_community_follow();
