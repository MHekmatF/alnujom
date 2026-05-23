-- Mirror of the inline RLS policies in supabase/migrations/20260522120001_create_listing_media.sql.
-- R-02 dual-storage invariant — both files MUST be kept in sync at PR review.

-- Public SELECT when parent listing is approved + publish window open
DROP POLICY IF EXISTS "listing_media_anon_select_when_approved" ON public.listing_media;
CREATE POLICY "listing_media_anon_select_when_approved"
ON public.listing_media FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_media.listing_id
      AND l.status = 'approved'
      AND (l.published_at IS NULL OR l.published_at <= now())
      AND (l.expires_at IS NULL OR l.expires_at > now())
  )
);

-- Owner SELECT — any status of own listing
DROP POLICY IF EXISTS "listing_media_owner_select" ON public.listing_media;
CREATE POLICY "listing_media_owner_select"
ON public.listing_media FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_media.listing_id
      AND l.publisher_user_id = auth.uid()
  )
);

-- Admin SELECT via listings.view_all
DROP POLICY IF EXISTS "listing_media_admin_select" ON public.listing_media;
CREATE POLICY "listing_media_admin_select"
ON public.listing_media FOR SELECT
TO authenticated
USING (public.current_user_has_permission('listings.view_all'));

-- Owner INSERT — composite gate per FR-006
DROP POLICY IF EXISTS "listing_media_owner_insert" ON public.listing_media;
CREATE POLICY "listing_media_owner_insert"
ON public.listing_media FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = listing_media.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- Owner UPDATE — composite gate; same as INSERT
DROP POLICY IF EXISTS "listing_media_owner_update" ON public.listing_media;
CREATE POLICY "listing_media_owner_update"
ON public.listing_media FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = listing_media.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = listing_media.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- Owner DELETE — composite gate; same as INSERT/UPDATE
DROP POLICY IF EXISTS "listing_media_owner_delete" ON public.listing_media;
CREATE POLICY "listing_media_owner_delete"
ON public.listing_media FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.listings l
    JOIN public.profiles p ON p.user_id = l.publisher_user_id
    WHERE l.id = listing_media.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
      AND p.publisher_status = 'approved'
      AND p.account_status = 'approved'
  )
);

-- Admin INSERT/UPDATE/DELETE via listings.edit_any
DROP POLICY IF EXISTS "listing_media_admin_write" ON public.listing_media;
CREATE POLICY "listing_media_admin_write"
ON public.listing_media FOR ALL
TO authenticated
USING (public.current_user_has_permission('listings.edit_any'))
WITH CHECK (public.current_user_has_permission('listings.edit_any'));
