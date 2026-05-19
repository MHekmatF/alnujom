-- Mirror of the inline RLS policies in supabase/migrations/20260519120002_create_listings.sql.
-- R-02 dual-storage invariant: both files MUST be kept in sync at PR review.

DROP POLICY IF EXISTS listings_select_public ON public.listings;
CREATE POLICY listings_select_public ON public.listings
  FOR SELECT TO anon, authenticated
  USING (
    status = 'approved'
    AND (published_at IS NULL OR published_at <= now())
    AND (expires_at  IS NULL OR expires_at  >  now())
  );

DROP POLICY IF EXISTS listings_select_owner ON public.listings;
CREATE POLICY listings_select_owner ON public.listings
  FOR SELECT TO authenticated
  USING (auth.uid() = publisher_user_id);

DROP POLICY IF EXISTS listings_select_admin ON public.listings;
CREATE POLICY listings_select_admin ON public.listings
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('listings.view_all'));

DROP POLICY IF EXISTS listings_insert_owner ON public.listings;
CREATE POLICY listings_insert_owner ON public.listings
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = publisher_user_id
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.user_id = auth.uid()
        AND p.publisher_status = 'approved'
        AND p.account_status   = 'approved'
    )
  );

DROP POLICY IF EXISTS listings_update_owner ON public.listings;
CREATE POLICY listings_update_owner ON public.listings
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = publisher_user_id
    AND status IN ('draft', 'rejected')
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.user_id = auth.uid()
        AND p.publisher_status = 'approved'
        AND p.account_status   = 'approved'
    )
  )
  WITH CHECK (
    auth.uid() = publisher_user_id
    AND status IN ('draft', 'pending_review')
  );

DROP POLICY IF EXISTS listings_update_admin ON public.listings;
CREATE POLICY listings_update_admin ON public.listings
  FOR UPDATE TO authenticated
  USING (public.current_user_has_permission('listings.edit_any'));

DROP POLICY IF EXISTS listings_delete_admin ON public.listings;
CREATE POLICY listings_delete_admin ON public.listings
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('listings.delete_any'));
