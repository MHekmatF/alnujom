-- Phase 10: Listing Creation - public.listing_details child table.
-- FR-003; child-derived ownership policies through public.listings.

CREATE TABLE IF NOT EXISTS public.listing_details (
  listing_id    UUID         PRIMARY KEY REFERENCES public.listings(id) ON DELETE CASCADE,
  description   TEXT,
  amenities     JSONB        NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(amenities) = 'array'),
  year_built    SMALLINT     CHECK (year_built IS NULL OR (year_built BETWEEN 1850 AND extract(year from now())::int + 2)),
  furnished     BOOLEAN,
  parking       BOOLEAN,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

ALTER TABLE public.listing_details ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_listing_details_set_updated_at ON public.listing_details;
CREATE TRIGGER trg_listing_details_set_updated_at
  BEFORE UPDATE ON public.listing_details
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP POLICY IF EXISTS listing_details_select_inherited ON public.listing_details;
CREATE POLICY listing_details_select_inherited ON public.listing_details
  FOR SELECT TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l WHERE l.id = listing_details.listing_id
    AND (
      (l.status = 'approved'
        AND (l.published_at IS NULL OR l.published_at <= now())
        AND (l.expires_at  IS NULL OR l.expires_at  >  now()))
      OR (auth.uid() = l.publisher_user_id)
      OR public.current_user_has_permission('listings.view_all')
    )
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
