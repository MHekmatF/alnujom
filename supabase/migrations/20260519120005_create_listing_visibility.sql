-- Phase 10: Listing Creation - public.listing_visibility child table.
-- FR-003; R-11 parent-column-authoritative sync trigger.

CREATE TABLE IF NOT EXISTS public.listing_visibility (
  listing_id           UUID         PRIMARY KEY REFERENCES public.listings(id) ON DELETE CASCADE,
  location_visibility  TEXT         NOT NULL CHECK (location_visibility IN ('hidden','approximate','exact','admin_only')),
  contact_visibility   TEXT         NOT NULL DEFAULT 'public' CHECK (contact_visibility IN ('public','admin_only')),
  hide_until           TIMESTAMPTZ,
  last_updated_by      UUID         REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

ALTER TABLE public.listing_visibility ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_listing_visibility_set_updated_at ON public.listing_visibility;
CREATE TRIGGER trg_listing_visibility_set_updated_at
  BEFORE UPDATE ON public.listing_visibility
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP POLICY IF EXISTS listing_visibility_select_inherited ON public.listing_visibility;
CREATE POLICY listing_visibility_select_inherited ON public.listing_visibility
  FOR SELECT TO anon, authenticated
  USING (EXISTS (
    SELECT 1 FROM public.listings l WHERE l.id = listing_visibility.listing_id
    AND (
      (l.status = 'approved'
        AND (l.published_at IS NULL OR l.published_at <= now())
        AND (l.expires_at  IS NULL OR l.expires_at  >  now()))
      OR (auth.uid() = l.publisher_user_id)
      OR public.current_user_has_permission('listings.view_all')
    )
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

CREATE OR REPLACE FUNCTION public.listing_visibility_sync_trigger_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.listing_visibility (listing_id, location_visibility, contact_visibility, last_updated_by)
  VALUES (NEW.id, NEW.location_visibility, NEW.contact_name_visibility, auth.uid())
  ON CONFLICT (listing_id) DO UPDATE
    SET location_visibility = EXCLUDED.location_visibility,
        contact_visibility  = EXCLUDED.contact_visibility,
        last_updated_by     = EXCLUDED.last_updated_by,
        updated_at          = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS listing_visibility_sync_trigger ON public.listings;
CREATE TRIGGER listing_visibility_sync_trigger
  AFTER INSERT OR UPDATE OF location_visibility, contact_name_visibility ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.listing_visibility_sync_trigger_fn();
