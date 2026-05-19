-- Phase 10: Listing Creation - public.listing_prices child table.
-- FR-003, SC-008/009/022; Phase 9 Q4; R-10 NUMERIC(14,2); R-12 one primary row; Q3 single-currency UI.

CREATE TABLE IF NOT EXISTS public.listing_prices (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id    UUID          NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  currency_code TEXT          NOT NULL REFERENCES public.currencies(code) ON DELETE RESTRICT,
  amount        NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  is_primary    BOOLEAN       NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  UNIQUE (listing_id, currency_code)
);

CREATE UNIQUE INDEX IF NOT EXISTS listing_prices_one_primary_idx
  ON public.listing_prices (listing_id)
  WHERE is_primary = true;

CREATE INDEX IF NOT EXISTS idx_listing_prices_listing_id ON public.listing_prices (listing_id);

ALTER TABLE public.listing_prices ENABLE ROW LEVEL SECURITY;

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
