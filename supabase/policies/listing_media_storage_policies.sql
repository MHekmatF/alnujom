-- Mirror of the inline RLS policies in supabase/migrations/20260522120003_create_listing_media_storage_policies.sql.
-- R-02 dual-storage invariant — both files MUST be kept in sync at PR review.
-- Total: 14 policies (7 per bucket × 2 buckets: listing-images, listing-videos).

-- ===========================================================================
-- Bucket: listing-images (7 policies)
-- ===========================================================================

-- 1. Anon SELECT when parent listing approved + publish window open
DROP POLICY IF EXISTS "listing_images_anon_select_when_approved" ON storage.objects;
CREATE POLICY "listing_images_anon_select_when_approved"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'listing-images'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.status = 'approved'
      AND (l.published_at IS NULL OR l.published_at <= now())
      AND (l.expires_at IS NULL OR l.expires_at > now())
  )
);

-- 2. Owner SELECT — any status of own listing
DROP POLICY IF EXISTS "listing_images_owner_select" ON storage.objects;
CREATE POLICY "listing_images_owner_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'listing-images'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
  )
);

-- 3. Admin SELECT via listings.view_all
DROP POLICY IF EXISTS "listing_images_admin_select" ON storage.objects;
CREATE POLICY "listing_images_admin_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'listing-images'
  AND public.current_user_has_permission('listings.view_all')
);

-- 4. Owner INSERT — composite gate + path-shape WITH CHECK (R-27)
DROP POLICY IF EXISTS "listing_images_owner_insert" ON storage.objects;
CREATE POLICY "listing_images_owner_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'listing-images'
  AND name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- 5. Owner UPDATE — same composite gate
DROP POLICY IF EXISTS "listing_images_owner_update" ON storage.objects;
CREATE POLICY "listing_images_owner_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'listing-images'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- 6. Owner DELETE — same composite gate
DROP POLICY IF EXISTS "listing_images_owner_delete" ON storage.objects;
CREATE POLICY "listing_images_owner_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'listing-images'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- 7. Admin INSERT/UPDATE/DELETE — single FOR ALL policy
DROP POLICY IF EXISTS "listing_images_admin_write" ON storage.objects;
CREATE POLICY "listing_images_admin_write"
ON storage.objects FOR ALL
TO authenticated
USING (
  bucket_id = 'listing-images'
  AND public.current_user_has_permission('listings.edit_any')
)
WITH CHECK (
  bucket_id = 'listing-images'
  AND public.current_user_has_permission('listings.edit_any')
);

-- ===========================================================================
-- Bucket: listing-videos (7 policies)
-- ===========================================================================

-- 1. Anon SELECT when parent listing approved + publish window open
DROP POLICY IF EXISTS "listing_videos_anon_select_when_approved" ON storage.objects;
CREATE POLICY "listing_videos_anon_select_when_approved"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'listing-videos'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.status = 'approved'
      AND (l.published_at IS NULL OR l.published_at <= now())
      AND (l.expires_at IS NULL OR l.expires_at > now())
  )
);

-- 2. Owner SELECT — any status of own listing
DROP POLICY IF EXISTS "listing_videos_owner_select" ON storage.objects;
CREATE POLICY "listing_videos_owner_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'listing-videos'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
  )
);

-- 3. Admin SELECT via listings.view_all
DROP POLICY IF EXISTS "listing_videos_admin_select" ON storage.objects;
CREATE POLICY "listing_videos_admin_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'listing-videos'
  AND public.current_user_has_permission('listings.view_all')
);

-- 4. Owner INSERT — composite gate + path-shape WITH CHECK (R-27)
DROP POLICY IF EXISTS "listing_videos_owner_insert" ON storage.objects;
CREATE POLICY "listing_videos_owner_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'listing-videos'
  AND name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- 5. Owner UPDATE — same composite gate
DROP POLICY IF EXISTS "listing_videos_owner_update" ON storage.objects;
CREATE POLICY "listing_videos_owner_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'listing-videos'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- 6. Owner DELETE — same composite gate
DROP POLICY IF EXISTS "listing_videos_owner_delete" ON storage.objects;
CREATE POLICY "listing_videos_owner_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'listing-videos'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = split_part(name, '/', 1)::uuid
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- 7. Admin INSERT/UPDATE/DELETE — single FOR ALL policy
DROP POLICY IF EXISTS "listing_videos_admin_write" ON storage.objects;
CREATE POLICY "listing_videos_admin_write"
ON storage.objects FOR ALL
TO authenticated
USING (
  bucket_id = 'listing-videos'
  AND public.current_user_has_permission('listings.edit_any')
)
WITH CHECK (
  bucket_id = 'listing-videos'
  AND public.current_user_has_permission('listings.edit_any')
);
