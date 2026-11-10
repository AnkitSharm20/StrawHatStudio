-- The legacy bucket currently has zero objects. New profile banners are uploaded to
-- profile-banners-private and resolved with short-lived signed URLs.
UPDATE storage.buckets SET public = false WHERE id = 'profile-banners';
DROP POLICY IF EXISTS "Profile banners public read" ON storage.objects;
DROP POLICY IF EXISTS "Profile banners visible to public profiles and owners" ON storage.objects;
CREATE POLICY "Legacy profile banners visible to public profiles and owners"
ON storage.objects FOR SELECT TO anon, authenticated
USING (
  bucket_id = 'profile-banners'
  AND EXISTS (
    SELECT 1 FROM public.profiles AS profile
    WHERE profile.id::text = (storage.foldername(name))[1]
      AND (profile.is_public IS TRUE OR profile.id = (SELECT auth.uid()))
  )
);
