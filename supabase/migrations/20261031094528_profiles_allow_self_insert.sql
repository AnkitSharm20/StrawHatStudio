-- Allow signed-in members to create only their own profile row.
-- Existing profile updates remain governed by the separate UPDATE policy.
create policy "Users insert own profile"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = id);
