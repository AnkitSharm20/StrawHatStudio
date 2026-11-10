-- Atomically claim webhook events and allow safe recovery after a stale processing lease.
create or replace function private.claim_razorpay_webhook_event(
  p_event_id text,
  p_event_type text,
  p_payload_hash text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_inserted text;
  v_event public.razorpay_webhook_events%rowtype;
begin
  if p_event_id is null or length(p_event_id) < 1 or length(p_event_id) > 128 then
    raise exception 'Invalid webhook event identifier';
  end if;

  insert into public.razorpay_webhook_events(
    event_id,event_type,payload_hash,status,processing_started_at,error_message
  ) values (
    p_event_id,left(coalesce(p_event_type,'unknown'),120),p_payload_hash,'processing',now(),null
  )
  on conflict (event_id) do nothing
  returning event_id into v_inserted;

  if v_inserted is not null then
    return true;
  end if;

  select * into v_event
  from public.razorpay_webhook_events
  where event_id = p_event_id
  for update;

  if not found or v_event.status = 'processed' then
    return false;
  end if;

  if v_event.status = 'processing'
     and coalesce(v_event.processing_started_at,v_event.received_at) > now() - interval '1 minute' then
    return false;
  end if;

  update public.razorpay_webhook_events
  set event_type=left(coalesce(p_event_type,'unknown'),120),
      payload_hash=p_payload_hash,
      status='processing',
      processing_started_at=now(),
      error_message=null
  where event_id=p_event_id;

  return true;
end;
$function$;
revoke all on function private.claim_razorpay_webhook_event(text,text,text) from public,anon,authenticated;
grant usage on schema private to service_role;
grant execute on function private.claim_razorpay_webhook_event(text,text,text) to service_role;
