-- Phase 10 follow-up — split the three child-table inherited SELECT policies
-- so anon doesn't trip the current_user_has_permission EXECUTE check.
--
-- Bug: the single *_select_inherited policy on listing_details / listing_prices
-- / listing_visibility was granted to {anon, authenticated} and OR'd
-- current_user_has_permission('listings.view_all') into the predicate. anon
-- has no EXECUTE on that function, so any anon SELECT errors with SQLSTATE
-- 42501 ("permission denied for function") instead of returning the
-- public-when-approved rows. Step 12 of quickstart.md (SC-005 anonymous read
-- of approved listings + their child rows) fails as a result.
--
-- Fix: mirror the parent listings table's role-scoped partition — one anon-
-- safe policy for the public-when-approved branch, one authenticated-only
-- policy for the owner-or-admin branch. The function call is now only
-- evaluated under the authenticated role.

-- ─── listing_details ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS listing_details_select_inherited ON public.listing_details;

CREATE POLICY listing_details_select_public ON public.listing_details
  FOR SELECT TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_details.listing_id
      AND l.status = 'approved'
      AND (l.published_at IS NULL OR l.published_at <= now())
      AND (l.expires_at IS NULL OR l.expires_at > now())
  ));

CREATE POLICY listing_details_select_owner_or_admin ON public.listing_details
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_details.listing_id
      AND (l.publisher_user_id = auth.uid()
           OR current_user_has_permission('listings.view_all'))
  ));

-- ─── listing_prices ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS listing_prices_select_inherited ON public.listing_prices;

CREATE POLICY listing_prices_select_public ON public.listing_prices
  FOR SELECT TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_prices.listing_id
      AND l.status = 'approved'
      AND (l.published_at IS NULL OR l.published_at <= now())
      AND (l.expires_at IS NULL OR l.expires_at > now())
  ));

CREATE POLICY listing_prices_select_owner_or_admin ON public.listing_prices
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_prices.listing_id
      AND (l.publisher_user_id = auth.uid()
           OR current_user_has_permission('listings.view_all'))
  ));

-- ─── listing_visibility ────────────────────────────────────────────────────
DROP POLICY IF EXISTS listing_visibility_select_inherited ON public.listing_visibility;

CREATE POLICY listing_visibility_select_public ON public.listing_visibility
  FOR SELECT TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_visibility.listing_id
      AND l.status = 'approved'
      AND (l.published_at IS NULL OR l.published_at <= now())
      AND (l.expires_at IS NULL OR l.expires_at > now())
  ));

CREATE POLICY listing_visibility_select_owner_or_admin ON public.listing_visibility
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_visibility.listing_id
      AND (l.publisher_user_id = auth.uid()
           OR current_user_has_permission('listings.view_all'))
  ));
