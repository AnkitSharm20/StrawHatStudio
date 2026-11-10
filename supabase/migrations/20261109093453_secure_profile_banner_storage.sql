-- Profile banners are private and readable only for public profiles or their owners.
UPDATE storage.buckets
SET public = false
WHERE id = 'profile-banners';

DROP POLICY IF EXISTS "Profile banners public read" ON storage.objects;

CREATE POLICY "Profile banners visible to public profiles and owners"
ON storage.objects
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'profile-banners'
  AND EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id::text = (storage.foldername(name))[1]
      AND (profile.is_public IS TRUE OR profile.id = (SELECT auth.uid()))
  )
);

-- Avatars remain intentionally public, separate from private profile banners.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-avatars',
  'profile-avatars',
  true,
  5242880,
  ARRAY['image/jpeg','image/png','image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE
SET public = true,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Profile avatars public read" ON storage.objects;
DROP POLICY IF EXISTS "Users upload own profile avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users update own profile avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users delete own profile avatars" ON storage.objects;

CREATE POLICY "Profile avatars public read"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'profile-avatars');

CREATE POLICY "Users upload own profile avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

CREATE POLICY "Users update own profile avatars"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profile-avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
)
WITH CHECK (
  bucket_id = 'profile-avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

CREATE POLICY "Users delete own profile avatars"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-avatars'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);
