-- Mirror of the inline RLS policies in supabase/migrations/20260519120004_create_listing_prices.sql.
-- R-02 dual-storage invariant: both files MUST be kept in sync at PR review.

DROP POLICY IF EXISTS listing_prices_select_inherited ON public.listing_prices;
CREATE POLICY listing_prices_select_inherited ON public.listing_prices
  FOR SELECT TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l WHERE l.id = listing_prices.listing_id
    AND (
      (l.status = 'approved'
        AND (l.published_at IS NULL OR l.published_at <= now())
        AND (l.expires_at  IS NULL OR l.expires_at  >  now()))
      OR (auth.uid() = l.publisher_user_id)
      OR public.current_user_has_permission('listings.view_all')
    )
  ));

DROP POLICY IF EXISTS listing_prices_write_owner ON public.listing_prices;
CREATE POLICY listing_prices_write_owner ON public.listing_prices
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_prices.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_prices.listing_id
      AND l.publisher_user_id = auth.uid()
      AND l.status IN ('draft', 'rejected')
  ));

DROP POLICY IF EXISTS listing_prices_admin ON public.listing_prices;
CREATE POLICY listing_prices_admin ON public.listing_prices
  FOR ALL TO authenticated
  USING (public.current_user_has_permission('listings.edit_any'))
  WITH CHECK (public.current_user_has_permission('listings.edit_any'));
