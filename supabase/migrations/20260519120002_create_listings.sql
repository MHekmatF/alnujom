-- Phase 10: Listing Creation - public.listings parent table.
-- FR-001/002/005/006; R-04 no broad anon carve-out; R-16 public-read-when-approved; R-17 agency_id has no FK in Phase 10.

CREATE TABLE IF NOT EXISTS public.listings (
  id                       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  publisher_user_id        UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  agency_id                UUID         NULL,
  purpose                  TEXT         NOT NULL CHECK (purpose IN ('sale','rent','daily_rent','investment')),
  property_type            TEXT         NOT NULL CHECK (property_type IN ('apartment','villa','land','shop','office','farm','warehouse','other')),
  status                   TEXT         NOT NULL DEFAULT 'draft'
                             CHECK (status IN ('draft','pending_review','approved','rejected','paused','sold','rented','expired','deleted')),
  title                    TEXT         NOT NULL CHECK (length(trim(title)) > 0),
  governorate_id           UUID         REFERENCES public.governorates(id) ON DELETE RESTRICT,
  city_id                  UUID         REFERENCES public.cities(id)        ON DELETE RESTRICT,
  area_id                  UUID         REFERENCES public.areas(id)         ON DELETE RESTRICT,
  address_text             TEXT,
  latitude                 NUMERIC(9,6),
  longitude                NUMERIC(9,6),
  location_visibility      TEXT         NOT NULL DEFAULT 'approximate'
                             CHECK (location_visibility IN ('hidden','approximate','exact','admin_only')),
  phone                    TEXT,
  whatsapp                 TEXT,
  contact_name_visibility  TEXT         NOT NULL DEFAULT 'public'
                             CHECK (contact_name_visibility IN ('public','admin_only')),
  area_size                NUMERIC(10,2) CHECK (area_size IS NULL OR area_size > 0),
  rooms                    SMALLINT      CHECK (rooms IS NULL OR rooms >= 0),
  bathrooms                SMALLINT      CHECK (bathrooms IS NULL OR bathrooms >= 0),
  floor                    SMALLINT,
  created_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
  published_at             TIMESTAMPTZ,
  expires_at               TIMESTAMPTZ
);

ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS trg_listings_set_updated_at ON public.listings;
CREATE TRIGGER trg_listings_set_updated_at
  BEFORE UPDATE ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_listings_publisher_status ON public.listings (publisher_user_id, status);
CREATE INDEX IF NOT EXISTS idx_listings_status_created   ON public.listings (status, created_at DESC) WHERE status = 'approved';
CREATE INDEX IF NOT EXISTS idx_listings_governorate      ON public.listings (governorate_id) WHERE status = 'approved';

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
