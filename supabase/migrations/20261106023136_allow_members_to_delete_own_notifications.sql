-- Allow members to delete only their own inbox notifications.
create policy "Members delete own notifications"
on public.studio_notifications
for delete
to authenticated
using (recipient_id = (select auth.uid()));
