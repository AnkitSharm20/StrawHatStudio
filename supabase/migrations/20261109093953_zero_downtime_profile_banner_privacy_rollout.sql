-- Keep the legacy public bucket available to the currently deployed frontend
-- until the new client is released. New clients use a separate private bucket.
UPDATE storage.buckets SET public = true WHERE id = 'profile-banners';
DROP POLICY IF EXISTS "Profile banners visible to public profiles and owners" ON storage.objects;
DROP POLICY IF EXISTS "Profile banners public read" ON storage.objects;
CREATE POLICY "Profile banners public read"
ON storage.objects FOR SELECT TO anon, authenticated
USING (bucket_id = 'profile-banners');

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-banners-private',
  'profile-banners-private',
  false,
  10485760,
  ARRAY['image/jpeg','image/png','image/webp','image/gif']::text[]
)
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Private profile banners visible to public profiles and owners" ON storage.objects;
DROP POLICY IF EXISTS "Users upload own private profile banners" ON storage.objects;
DROP POLICY IF EXISTS "Users update own private profile banners" ON storage.objects;
DROP POLICY IF EXISTS "Users delete own private profile banners" ON storage.objects;

CREATE POLICY "Private profile banners visible to public profiles and owners"
ON storage.objects FOR SELECT TO anon, authenticated
USING (
  bucket_id = 'profile-banners-private'
  AND EXISTS (
    SELECT 1 FROM public.profiles AS profile
    WHERE profile.id::text = (storage.foldername(name))[1]
      AND (profile.is_public IS TRUE OR profile.id = (SELECT auth.uid()))
  )
);

CREATE POLICY "Users upload own private profile banners"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'profile-banners-private'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

CREATE POLICY "Users update own private profile banners"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'profile-banners-private'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
)
WITH CHECK (
  bucket_id = 'profile-banners-private'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

CREATE POLICY "Users delete own private profile banners"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'profile-banners-private'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);
