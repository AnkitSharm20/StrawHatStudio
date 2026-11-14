drop policy "Creators delete media for pending anime moments" on storage.objects;
create policy "Creators delete their own anime moment uploads"
on storage.objects for delete to authenticated
using (
  bucket_id = 'anime-moments'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
