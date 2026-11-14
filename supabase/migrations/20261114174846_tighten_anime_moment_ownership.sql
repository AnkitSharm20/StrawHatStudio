-- Tighten Anime Moments ownership: creators can only reference their own upload folder
-- and cannot mutate ownership or media object paths after submission.
drop policy "Members submit their own pending anime moments" on public.anime_moments;
create policy "Members submit their own pending anime moments"
on public.anime_moments for insert to authenticated
with check (
  creator_id = (select auth.uid())
  and status = 'pending'
  and media_path like ((select auth.uid())::text || '/%')
);

revoke update on public.anime_moments from authenticated;
grant update (caption, status, updated_at, published_at) on public.anime_moments to authenticated;
