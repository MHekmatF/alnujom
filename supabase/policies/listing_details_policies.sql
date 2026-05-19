-- Mirror of the inline RLS policies in supabase/migrations/20260519120003_create_listing_details.sql
-- + the follow-up split in 20260519120010_fix_listings_child_anon_select_split.sql.
-- R-02 dual-storage invariant: both files MUST be kept in sync at PR review.

DROP POLICY IF EXISTS listing_details_select_inherited ON public.listing_details;
DROP POLICY IF EXISTS listing_details_select_public ON public.listing_details;
DROP POLICY IF EXISTS listing_details_select_owner_or_admin ON public.listing_details;

-- Public-when-approved — anon-safe (no function call in the predicate so anon
-- doesn't trip the current_user_has_permission EXECUTE check).
CREATE POLICY listing_details_select_public ON public.listing_details
  FOR SELECT TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_details.listing_id
      AND l.status = 'approved'
      AND (l.published_at IS NULL OR l.published_at <= now())
      AND (l.expires_at  IS NULL OR l.expires_at  >  now())
  ));

-- Owner-or-admin — authenticated only. Function call is safe here because
-- the function has EXECUTE granted to authenticated.
CREATE POLICY listing_details_select_owner_or_admin ON public.listing_details
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_details.listing_id
      AND (l.publisher_user_id = auth.uid()
           OR public.current_user_has_permission('listings.view_all'))
  ));

DROP POLICY IF EXISTS listing_details_write_owner ON public.listing_details;
CREATE POLICY listing_details_write_owner ON public.listing_details
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_details.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_details.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
  ));

DROP POLICY IF EXISTS listing_details_admin ON public.listing_details;
CREATE POLICY listing_details_admin ON public.listing_details
  FOR ALL TO authenticated
  USING (public.current_user_has_permission('listings.edit_any'))
  WITH CHECK (public.current_user_has_permission('listings.edit_any'));
