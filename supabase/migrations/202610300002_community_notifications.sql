-- Notification generation is intentionally server-side via database triggers.
create schema if not exists private;
revoke all on schema private from public,anon,authenticated;
create or replace function private.notify_community_reply() returns trigger language plpgsql security definer set search_path='' as $$
declare v_owner uuid;
begin
 if auth.uid() is null or auth.uid()<>new.author_id then raise exception 'Authenticated author context required'; end if;
 select author_id into v_owner from public.community_posts where id=new.post_id;
 if v_owner is not null and v_owner<>new.author_id then
  insert into public.studio_notifications(recipient_id,actor_id,kind,entity_type,entity_id,message)
  values(v_owner,new.author_id,'reply','post',new.post_id,'Someone replied to your post.');
 end if;
 return new;
end; $$;
create or replace function private.notify_community_reaction() returns trigger language plpgsql security definer set search_path='' as $$
declare v_owner uuid;
begin
 if auth.uid() is null or auth.uid()<>new.user_id then raise exception 'Authenticated reactor context required'; end if;
 select author_id into v_owner from public.community_posts where id=new.post_id;
 if v_owner is not null and v_owner<>new.user_id then
  insert into public.studio_notifications(recipient_id,actor_id,kind,entity_type,entity_id,message)
  values(v_owner,new.user_id,'reaction','post',new.post_id,'Someone reacted to your post.');
 end if;
 return new;
end; $$;
drop trigger if exists community_reply_notification on public.community_replies;
create trigger community_reply_notification after insert on public.community_replies for each row execute function private.notify_community_reply();
drop trigger if exists community_reaction_notification on public.community_post_reactions;
create trigger community_reaction_notification after insert on public.community_post_reactions for each row execute function private.notify_community_reaction();
