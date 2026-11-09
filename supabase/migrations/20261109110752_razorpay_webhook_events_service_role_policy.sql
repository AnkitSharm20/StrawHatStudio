-- Internal webhook inbox is writable only by trusted server-side service_role.
drop policy if exists razorpay_webhook_events_service_role_only on public.razorpay_webhook_events;
create policy razorpay_webhook_events_service_role_only
on public.razorpay_webhook_events
for all
to service_role
using (true)
with check (true);
