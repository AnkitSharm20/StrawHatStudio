create table public.admin_audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  actor_role text not null default 'admin' check (actor_role = 'admin'),
  action text not null check (action in ('INSERT','UPDATE','DELETE')),
  target_table text not null,
  target_id text not null,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

alter table public.admin_audit_logs enable row level security;

revoke all on table public.admin_audit_logs from public, anon, authenticated;
grant select on table public.admin_audit_logs to authenticated;
grant select on table public.admin_audit_logs to service_role;

create policy "Admins read audit logs"
on public.admin_audit_logs
for select
to authenticated
using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create index admin_audit_logs_created_at_idx
on public.admin_audit_logs (created_at desc);

create index admin_audit_logs_target_idx
on public.admin_audit_logs (target_table, target_id, created_at desc);

create or replace function private.capture_admin_audit_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_claims jsonb := auth.jwt();
  v_actor_id uuid := auth.uid();
  v_before_row jsonb;
  v_after_row jsonb;
  v_before jsonb;
  v_after jsonb;
  v_target_id text;
  v_action text := tg_op;
begin
  if coalesce(v_claims -> 'app_metadata' ->> 'role', '') <> 'admin'
     or v_actor_id is null then
    if tg_op = 'DELETE' then return old; else return new; end if;
  end if;

  if tg_op = 'UPDATE' and to_jsonb(old) is not distinct from to_jsonb(new) then
    return new;
  end if;

  if tg_op = 'DELETE' then
    v_before_row := to_jsonb(old);
  else
    v_after_row := to_jsonb(new);
  end if;

  if tg_op = 'UPDATE' then
    v_before_row := to_jsonb(old);
    v_after_row := to_jsonb(new);
  end if;

  v_target_id := coalesce(v_after_row ->> 'id', v_before_row ->> 'id',
                          v_after_row ->> 'key', v_before_row ->> 'key', 'unknown');

  case tg_table_name
    when 'media_assets' then
      if v_before_row is not null then
        v_before := jsonb_strip_nulls(jsonb_build_object(
          'id', v_before_row -> 'id', 'title', v_before_row -> 'title',
          'media_type', v_before_row -> 'media_type', 'mime_type', v_before_row -> 'mime_type',
          'file_size_bytes', v_before_row -> 'file_size_bytes',
          'placement', v_before_row -> 'placement', 'is_published', v_before_row -> 'is_published'
        ));
      end if;
      if v_after_row is not null then
        v_after := jsonb_strip_nulls(jsonb_build_object(
          'id', v_after_row -> 'id', 'title', v_after_row -> 'title',
          'media_type', v_after_row -> 'media_type', 'mime_type', v_after_row -> 'mime_type',
          'file_size_bytes', v_after_row -> 'file_size_bytes',
          'placement', v_after_row -> 'placement', 'is_published', v_after_row -> 'is_published'
        ));
      end if;
    when 'community_reports' then
      if v_before_row is not null then
        v_before := jsonb_strip_nulls(jsonb_build_object(
          'id', v_before_row -> 'id', 'post_id', v_before_row -> 'post_id',
          'reply_id', v_before_row -> 'reply_id', 'reason', v_before_row -> 'reason',
          'status', v_before_row -> 'status'
        ));
      end if;
      if v_after_row is not null then
        v_after := jsonb_strip_nulls(jsonb_build_object(
          'id', v_after_row -> 'id', 'post_id', v_after_row -> 'post_id',
          'reply_id', v_after_row -> 'reply_id', 'reason', v_after_row -> 'reason',
          'status', v_after_row -> 'status'
        ));
      end if;
    when 'community_posts' then
      if v_before_row is not null then
        v_before := jsonb_strip_nulls(jsonb_build_object(
          'id', v_before_row -> 'id', 'author_id', v_before_row -> 'author_id',
          'status', v_before_row -> 'status'
        ));
      end if;
      if v_after_row is not null then
        v_after := jsonb_strip_nulls(jsonb_build_object(
          'id', v_after_row -> 'id', 'author_id', v_after_row -> 'author_id',
          'status', v_after_row -> 'status'
        ));
      end if;
    when 'community_replies' then
      if v_before_row is not null then
        v_before := jsonb_strip_nulls(jsonb_build_object(
          'id', v_before_row -> 'id', 'post_id', v_before_row -> 'post_id',
          'author_id', v_before_row -> 'author_id', 'status', v_before_row -> 'status'
        ));
      end if;
      if v_after_row is not null then
        v_after := jsonb_strip_nulls(jsonb_build_object(
          'id', v_after_row -> 'id', 'post_id', v_after_row -> 'post_id',
          'author_id', v_after_row -> 'author_id', 'status', v_after_row -> 'status'
        ));
      end if;
    when 'shop_items' then
      if v_before_row is not null then
        v_before := jsonb_strip_nulls(jsonb_build_object(
          'id', v_before_row -> 'id', 'slug', v_before_row -> 'slug',
          'name', v_before_row -> 'name', 'item_type', v_before_row -> 'item_type',
          'coin_price', v_before_row -> 'coin_price', 'is_active', v_before_row -> 'is_active'
        ));
      end if;
      if v_after_row is not null then
        v_after := jsonb_strip_nulls(jsonb_build_object(
          'id', v_after_row -> 'id', 'slug', v_after_row -> 'slug',
          'name', v_after_row -> 'name', 'item_type', v_after_row -> 'item_type',
          'coin_price', v_after_row -> 'coin_price', 'is_active', v_after_row -> 'is_active'
        ));
      end if;
    when 'site_config' then
      if v_before_row is not null then
        v_before := jsonb_build_object('key', v_before_row -> 'key');
      end if;
      if v_after_row is not null then
        v_after := jsonb_build_object('key', v_after_row -> 'key');
      end if;
    when 'ad_slots' then
      if v_before_row is not null then
        v_before := jsonb_strip_nulls(jsonb_build_object(
          'id', v_before_row -> 'id', 'slot_key', v_before_row -> 'slot_key',
          'label', v_before_row -> 'label', 'is_enabled', v_before_row -> 'is_enabled',
          'starts_at', v_before_row -> 'starts_at', 'ends_at', v_before_row -> 'ends_at'
        ));
      end if;
      if v_after_row is not null then
        v_after := jsonb_strip_nulls(jsonb_build_object(
          'id', v_after_row -> 'id', 'slot_key', v_after_row -> 'slot_key',
          'label', v_after_row -> 'label', 'is_enabled', v_after_row -> 'is_enabled',
          'starts_at', v_after_row -> 'starts_at', 'ends_at', v_after_row -> 'ends_at'
        ));
      end if;
    when 'redeem_codes' then
      if v_before_row is not null then
        v_before := jsonb_strip_nulls(jsonb_build_object(
          'id', v_before_row -> 'id', 'reward_coins', v_before_row -> 'reward_coins',
          'max_redemptions', v_before_row -> 'max_redemptions',
          'redemption_count', v_before_row -> 'redemption_count',
          'expires_at', v_before_row -> 'expires_at', 'is_active', v_before_row -> 'is_active'
        ));
      end if;
      if v_after_row is not null then
        v_after := jsonb_strip_nulls(jsonb_build_object(
          'id', v_after_row -> 'id', 'reward_coins', v_after_row -> 'reward_coins',
          'max_redemptions', v_after_row -> 'max_redemptions',
          'redemption_count', v_after_row -> 'redemption_count',
          'expires_at', v_after_row -> 'expires_at', 'is_active', v_after_row -> 'is_active'
        ));
      end if;
  end case;

  insert into public.admin_audit_logs (
    actor_id, actor_role, action, target_table, target_id, before_data, after_data
  ) values (
    v_actor_id, 'admin', v_action, tg_table_name, v_target_id, v_before, v_after
  );

  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$function$;

revoke all on function private.capture_admin_audit_log() from public, anon, authenticated, service_role;

create trigger admin_audit_media_assets
after insert or update or delete on public.media_assets
for each row execute function private.capture_admin_audit_log();

create trigger admin_audit_community_reports
after update on public.community_reports
for each row execute function private.capture_admin_audit_log();

create trigger admin_audit_community_posts
after update on public.community_posts
for each row execute function private.capture_admin_audit_log();

create trigger admin_audit_community_replies
after update on public.community_replies
for each row execute function private.capture_admin_audit_log();

create trigger admin_audit_shop_items
after insert or update or delete on public.shop_items
for each row execute function private.capture_admin_audit_log();

create trigger admin_audit_site_config
after insert or update or delete on public.site_config
for each row execute function private.capture_admin_audit_log();

create trigger admin_audit_ad_slots
after insert or update or delete on public.ad_slots
for each row execute function private.capture_admin_audit_log();

create trigger admin_audit_redeem_codes
after insert or update or delete on public.redeem_codes
for each row execute function private.capture_admin_audit_log();

create or replace function public.get_admin_audit_logs()
returns setof jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select to_jsonb(log_row)
  from public.admin_audit_logs as log_row
  order by log_row.created_at desc
  limit 100
$function$;

revoke all on function public.get_admin_audit_logs() from public, anon;
grant execute on function public.get_admin_audit_logs() to authenticated;
grant execute on function public.get_admin_audit_logs() to service_role;
