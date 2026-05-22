-- Mirror of the inline RLS policies in supabase/migrations/20260519120005_create_listing_visibility.sql
-- + the follow-up split in 20260519120010_fix_listings_child_anon_select_split.sql.
-- R-02 dual-storage invariant: both files MUST be kept in sync at PR review.

DROP POLICY IF EXISTS listing_visibility_select_inherited ON public.listing_visibility;
DROP POLICY IF EXISTS listing_visibility_select_public ON public.listing_visibility;
DROP POLICY IF EXISTS listing_visibility_select_owner_or_admin ON public.listing_visibility;

CREATE POLICY listing_visibility_select_public ON public.listing_visibility
  FOR SELECT TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_visibility.listing_id
      AND l.status = 'approved'
      AND (l.published_at IS NULL OR l.published_at <= now())
      AND (l.expires_at  IS NULL OR l.expires_at  >  now())
  ));

CREATE POLICY listing_visibility_select_owner_or_admin ON public.listing_visibility
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_visibility.listing_id
      AND (l.publisher_user_id = auth.uid()
           OR public.current_user_has_permission('listings.view_all'))
  ));

DROP POLICY IF EXISTS listing_visibility_write_owner ON public.listing_visibility;
CREATE POLICY listing_visibility_write_owner ON public.listing_visibility
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_visibility.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_visibility.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
  ));

DROP POLICY IF EXISTS listing_visibility_admin ON public.listing_visibility;
CREATE POLICY listing_visibility_admin ON public.listing_visibility
  FOR ALL TO authenticated
  USING (public.current_user_has_permission('listings.edit_any'))
  WITH CHECK (public.current_user_has_permission('listings.edit_any'));
