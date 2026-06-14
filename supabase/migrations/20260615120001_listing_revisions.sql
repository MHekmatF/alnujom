-- Phase 031 (WS-B) — Stay-live edit revisions.
--
-- An APPROVED listing must stay public on its OLD content while the publisher
-- edits a staged copy that re-enters moderation. We model that with a side
-- table `public.listing_revisions` (one open revision per listing) plus a set
-- of SECURITY DEFINER RPCs:
--   begin_listing_revision  — owner snapshots the live listing into a draft revision
--   save_listing_revision   — owner stages field/media edits onto the revision
--   submit_listing_revision — owner moves the revision to pending_review
--   apply_listing_revision  — admin writes the proposal back onto the live listing
--   reject_listing_revision — admin rejects the revision
--
-- LEAK NOTE (verified, no view change): the public projection
-- `public.v_listings_public` (migration 20260525120002) and the
-- `search_listings` RPC read ONLY `public.listings` (status='approved'). The
-- `listing_revisions` side table is never joined into any public view, so a
-- staged-but-unapproved proposal CANNOT leak to the browse/search surfaces.
-- The live listing keeps serving its previously-approved content until an
-- admin applies the revision.

-- ===========================================================================
-- 1. TABLE public.listing_revisions
-- ===========================================================================

CREATE TABLE IF NOT EXISTS public.listing_revisions (
  id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id         UUID         NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  publisher_user_id  UUID         NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  proposed           JSONB        NOT NULL,
  media_manifest     JSONB        NOT NULL DEFAULT ('[]'::jsonb),
  status             TEXT         NOT NULL DEFAULT 'pending_review'
                       CHECK (status IN ('draft','pending_review','approved','rejected')),
  reject_reason      JSONB,
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.listing_revisions IS
  'Phase 031 (WS-B) — staged edit of an APPROVED listing. The live listing stays '
  'public on old content until an admin applies the revision. proposed = editable '
  'scalar/detail/price fields; media_manifest = ordered array of '
  '{storage_path, kind, is_main, ordering, thumbnail_path}. One open '
  '(draft/pending_review) revision per listing.';

-- One open revision per listing (draft or pending_review).
CREATE UNIQUE INDEX IF NOT EXISTS listing_revisions_one_open_idx
  ON public.listing_revisions (listing_id)
  WHERE status IN ('draft', 'pending_review');

CREATE INDEX IF NOT EXISTS listing_revisions_listing_idx
  ON public.listing_revisions (listing_id);

CREATE INDEX IF NOT EXISTS listing_revisions_pending_created_idx
  ON public.listing_revisions (created_at ASC)
  WHERE status = 'pending_review';

-- set_updated_at trigger (Phase 4 helper reused unchanged).
DROP TRIGGER IF EXISTS trg_listing_revisions_set_updated_at ON public.listing_revisions;
CREATE TRIGGER trg_listing_revisions_set_updated_at
  BEFORE UPDATE ON public.listing_revisions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ===========================================================================
-- 2. Row Level Security
--    owner (publisher_user_id = auth.uid()) full CRUD;
--    admin SELECT/UPDATE via current_user_has_permission('listings.review').
-- ===========================================================================

ALTER TABLE public.listing_revisions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS listing_revisions_owner_select ON public.listing_revisions;
CREATE POLICY listing_revisions_owner_select ON public.listing_revisions
  FOR SELECT TO authenticated
  USING (listing_revisions.publisher_user_id = auth.uid());

DROP POLICY IF EXISTS listing_revisions_owner_insert ON public.listing_revisions;
CREATE POLICY listing_revisions_owner_insert ON public.listing_revisions
  FOR INSERT TO authenticated
  WITH CHECK (listing_revisions.publisher_user_id = auth.uid());

DROP POLICY IF EXISTS listing_revisions_owner_update ON public.listing_revisions;
CREATE POLICY listing_revisions_owner_update ON public.listing_revisions
  FOR UPDATE TO authenticated
  USING (listing_revisions.publisher_user_id = auth.uid())
  WITH CHECK (listing_revisions.publisher_user_id = auth.uid());

DROP POLICY IF EXISTS listing_revisions_owner_delete ON public.listing_revisions;
CREATE POLICY listing_revisions_owner_delete ON public.listing_revisions
  FOR DELETE TO authenticated
  USING (listing_revisions.publisher_user_id = auth.uid());

DROP POLICY IF EXISTS listing_revisions_admin_select ON public.listing_revisions;
CREATE POLICY listing_revisions_admin_select ON public.listing_revisions
  FOR SELECT TO authenticated
  USING (public.current_user_has_permission('listings.review'));

DROP POLICY IF EXISTS listing_revisions_admin_update ON public.listing_revisions;
CREATE POLICY listing_revisions_admin_update ON public.listing_revisions
  FOR UPDATE TO authenticated
  USING (public.current_user_has_permission('listings.review'))
  WITH CHECK (public.current_user_has_permission('listings.review'));

-- RLS gates writes; grant the table verbs to authenticated only.
REVOKE ALL ON TABLE public.listing_revisions FROM PUBLIC;
REVOKE ALL ON TABLE public.listing_revisions FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.listing_revisions TO authenticated;

-- ===========================================================================
-- 3. begin_listing_revision(p_listing_id)
--    Owner-only. Only when listing.status='approved'. If an open revision
--    already exists, returns it; otherwise snapshots the live listing's
--    editable scalar/detail/price fields into `proposed` and the live media
--    into `media_manifest`, status='draft'. Returns the revision id.
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.begin_listing_revision(p_listing_id UUID)
RETURNS UUID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_listing    public.listings%ROWTYPE;
  v_existing   UUID;
  v_proposed   JSONB;
  v_manifest   JSONB;
  v_new_id     UUID;
BEGIN
  SELECT l.* INTO v_listing FROM public.listings AS l WHERE l.id = p_listing_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'listing not found';
  END IF;

  IF v_listing.publisher_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'not the owner';
  END IF;

  IF v_listing.status <> 'approved' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'revision can only be started on an approved listing';
  END IF;

  -- Return any already-open revision (one open per listing).
  SELECT lr.id INTO v_existing
  FROM public.listing_revisions AS lr
  WHERE lr.listing_id = p_listing_id
    AND lr.status IN ('draft', 'pending_review')
  ORDER BY lr.created_at DESC
  LIMIT 1;
  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  -- Snapshot the live editable scalar + detail + primary-price fields.
  v_proposed := jsonb_build_object(
    'title',                    v_listing.title,
    'purpose',                  v_listing.purpose,
    'property_type',            v_listing.property_type,
    'governorate_id',           v_listing.governorate_id,
    'city_id',                  v_listing.city_id,
    'area_id',                  v_listing.area_id,
    'address_text',             v_listing.address_text,
    'latitude',                 v_listing.latitude,
    'longitude',                v_listing.longitude,
    'location_visibility',      v_listing.location_visibility,
    'contact_name_visibility',  v_listing.contact_name_visibility,
    'phone',                    v_listing.phone,
    'whatsapp',                 v_listing.whatsapp,
    'area_size',                v_listing.area_size,
    'rooms',                    v_listing.rooms,
    'bathrooms',                v_listing.bathrooms,
    'floor',                    v_listing.floor
  );

  -- Fold in the listing_details child row (description / amenities / etc).
  v_proposed := v_proposed || COALESCE(
    (
      SELECT jsonb_build_object(
        'description', ld.description,
        'amenities',   ld.amenities,
        'year_built',  ld.year_built,
        'furnished',   ld.furnished,
        'parking',     ld.parking
      )
      FROM public.listing_details AS ld
      WHERE ld.listing_id = p_listing_id
    ),
    jsonb_build_object(
      'description', NULL,
      'amenities',   '[]'::jsonb,
      'year_built',  NULL,
      'furnished',   NULL,
      'parking',     NULL
    )
  );

  -- Fold in the primary price (currency + amount), if any.
  v_proposed := v_proposed || COALESCE(
    (
      SELECT jsonb_build_object(
        'price_currency_code', lp.currency_code,
        'price_amount',        lp.amount
      )
      FROM public.listing_prices AS lp
      WHERE lp.listing_id = p_listing_id
        AND lp.is_primary = true
      LIMIT 1
    ),
    jsonb_build_object('price_currency_code', NULL, 'price_amount', NULL)
  );

  -- Snapshot the live media as an ordered manifest.
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'storage_path',   lm.storage_path,
        'kind',           lm.kind,
        'is_main',        lm.is_main,
        'ordering',       lm.ordering,
        'thumbnail_path', lm.thumbnail_path
      )
      ORDER BY lm.ordering ASC, lm.created_at ASC
    ),
    '[]'::jsonb
  )
  INTO v_manifest
  FROM public.listing_media AS lm
  WHERE lm.listing_id = p_listing_id;

  INSERT INTO public.listing_revisions (
    listing_id, publisher_user_id, proposed, media_manifest, status
  )
  VALUES (p_listing_id, auth.uid(), v_proposed, v_manifest, 'draft')
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

REVOKE ALL ON FUNCTION public.begin_listing_revision(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.begin_listing_revision(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.begin_listing_revision(UUID) TO authenticated;

-- ===========================================================================
-- 4. save_listing_revision(p_revision_id, p_proposed, p_media_manifest)
--    Owner-only, draft/pending. Replaces the staged proposal + manifest.
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.save_listing_revision(
  p_revision_id    UUID,
  p_proposed       JSONB,
  p_media_manifest JSONB
)
RETURNS VOID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rev public.listing_revisions%ROWTYPE;
BEGIN
  SELECT lr.* INTO v_rev
  FROM public.listing_revisions AS lr
  WHERE lr.id = p_revision_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'revision not found';
  END IF;

  IF v_rev.publisher_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'not the owner';
  END IF;

  IF v_rev.status NOT IN ('draft', 'pending_review') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'revision is not editable';
  END IF;

  UPDATE public.listing_revisions AS lr
     SET proposed       = COALESCE(p_proposed, lr.proposed),
         media_manifest = COALESCE(p_media_manifest, lr.media_manifest)
   WHERE lr.id = p_revision_id;
END;
$$;

REVOKE ALL ON FUNCTION public.save_listing_revision(UUID, JSONB, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.save_listing_revision(UUID, JSONB, JSONB) FROM anon;
GRANT EXECUTE ON FUNCTION public.save_listing_revision(UUID, JSONB, JSONB) TO authenticated;

-- ===========================================================================
-- 5. submit_listing_revision(p_revision_id)
--    Owner-only. Moves the revision to pending_review. The LIVE listing stays
--    approved — we deliberately do NOT touch public.listings here.
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.submit_listing_revision(p_revision_id UUID)
RETURNS VOID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rev public.listing_revisions%ROWTYPE;
BEGIN
  SELECT lr.* INTO v_rev
  FROM public.listing_revisions AS lr
  WHERE lr.id = p_revision_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'revision not found';
  END IF;

  IF v_rev.publisher_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'not the owner';
  END IF;

  IF v_rev.status NOT IN ('draft', 'pending_review') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'revision cannot be submitted in its current status';
  END IF;

  UPDATE public.listing_revisions AS lr
     SET status        = 'pending_review',
         reject_reason = NULL
   WHERE lr.id = p_revision_id;
  -- NOTE: the live listing (public.listings) is intentionally untouched — it
  -- remains 'approved' and public on its old content until apply.
END;
$$;

REVOKE ALL ON FUNCTION public.submit_listing_revision(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_listing_revision(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.submit_listing_revision(UUID) TO authenticated;

-- ===========================================================================
-- 6. apply_listing_revision(p_revision_id)
--    Admin (listings.review). In ONE transaction: write proposed back onto
--    public.listings (+ listing_details + primary listing_prices), reconcile
--    public.listing_media to exactly match media_manifest, keep the listing
--    approved (published_at unchanged), set revision status='approved'.
--    Audited like the approve/reject wrappers (writes an audit_logs row).
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.apply_listing_revision(p_revision_id UUID)
RETURNS VOID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rev          public.listing_revisions%ROWTYPE;
  v_listing_id   UUID;
  v_proposed     JSONB;
  v_manifest     JSONB;
  v_currency     TEXT;
  v_amount       NUMERIC;
  v_item         JSONB;
  v_keep_paths   TEXT[];
BEGIN
  IF NOT public.current_user_has_permission('listings.review') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'permission denied';
  END IF;

  SELECT lr.* INTO v_rev
  FROM public.listing_revisions AS lr
  WHERE lr.id = p_revision_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'revision not found';
  END IF;

  IF v_rev.status <> 'pending_review' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'revision is not pending review';
  END IF;

  v_listing_id := v_rev.listing_id;
  v_proposed   := v_rev.proposed;
  v_manifest   := COALESCE(v_rev.media_manifest, '[]'::jsonb);

  -- --- 6a. Write proposed scalar fields back onto public.listings. ---------
  -- published_at + status + expires_at are deliberately NOT updated; the
  -- listing stays approved and public. The listings_audit_trigger fires on
  -- this UPDATE and records a listing.updated audit row.
  UPDATE public.listings AS l
     SET title                   = COALESCE(v_proposed->>'title', l.title),
         purpose                 = COALESCE(v_proposed->>'purpose', l.purpose),
         property_type           = COALESCE(v_proposed->>'property_type', l.property_type),
         governorate_id          = NULLIF(v_proposed->>'governorate_id', '')::uuid,
         city_id                 = NULLIF(v_proposed->>'city_id', '')::uuid,
         area_id                 = NULLIF(v_proposed->>'area_id', '')::uuid,
         address_text            = v_proposed->>'address_text',
         latitude                = NULLIF(v_proposed->>'latitude', '')::numeric,
         longitude               = NULLIF(v_proposed->>'longitude', '')::numeric,
         location_visibility     = COALESCE(v_proposed->>'location_visibility', l.location_visibility),
         contact_name_visibility = COALESCE(v_proposed->>'contact_name_visibility', l.contact_name_visibility),
         phone                   = v_proposed->>'phone',
         whatsapp                = v_proposed->>'whatsapp',
         area_size               = NULLIF(v_proposed->>'area_size', '')::numeric,
         rooms                   = NULLIF(v_proposed->>'rooms', '')::smallint,
         bathrooms               = NULLIF(v_proposed->>'bathrooms', '')::smallint,
         floor                   = NULLIF(v_proposed->>'floor', '')::smallint
   WHERE l.id = v_listing_id;

  -- --- 6b. Upsert the listing_details child row. --------------------------
  INSERT INTO public.listing_details AS ld (
    listing_id, description, amenities, year_built, furnished, parking
  )
  VALUES (
    v_listing_id,
    v_proposed->>'description',
    COALESCE(v_proposed->'amenities', '[]'::jsonb),
    NULLIF(v_proposed->>'year_built', '')::smallint,
    (v_proposed->>'furnished')::boolean,
    (v_proposed->>'parking')::boolean
  )
  ON CONFLICT (listing_id) DO UPDATE
    SET description = EXCLUDED.description,
        amenities   = EXCLUDED.amenities,
        year_built  = EXCLUDED.year_built,
        furnished   = EXCLUDED.furnished,
        parking     = EXCLUDED.parking;

  -- --- 6c. Reconcile the primary price. -----------------------------------
  v_currency := NULLIF(v_proposed->>'price_currency_code', '');
  v_amount   := NULLIF(v_proposed->>'price_amount', '')::numeric;
  IF v_currency IS NOT NULL AND v_amount IS NOT NULL AND v_amount > 0 THEN
    -- Drop any existing primary-priced rows whose currency differs (the
    -- UNIQUE(listing_id, currency_code) would otherwise block the upsert).
    DELETE FROM public.listing_prices AS lp
    WHERE lp.listing_id = v_listing_id
      AND lp.is_primary = true
      AND lp.currency_code <> v_currency;

    INSERT INTO public.listing_prices AS lp (
      listing_id, currency_code, amount, is_primary
    )
    VALUES (v_listing_id, v_currency, v_amount, true)
    ON CONFLICT (listing_id, currency_code) DO UPDATE
      SET amount     = EXCLUDED.amount,
          is_primary = true;
  END IF;

  -- --- 6d. Reconcile listing_media to exactly match the manifest. ---------
  -- Collect the storage paths the manifest wants to keep.
  SELECT COALESCE(array_agg(elem->>'storage_path'), ARRAY[]::text[])
  INTO v_keep_paths
  FROM jsonb_array_elements(v_manifest) AS elem
  WHERE elem->>'storage_path' IS NOT NULL;

  -- Delete live media rows whose storage_path is absent from the manifest.
  -- ORPHAN STORAGE NOTE: the underlying bucket objects for these deleted rows
  -- are NOT removed here (storage cleanup is out-of-band, like the existing
  -- delete-media reconciliation job). We do not fail the apply on storage.
  DELETE FROM public.listing_media AS lm
  WHERE lm.listing_id = v_listing_id
    AND (lm.storage_path IS NULL OR NOT (lm.storage_path = ANY (v_keep_paths)));

  -- Upsert/insert each manifest entry by (listing_id, storage_path).
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_manifest)
  LOOP
    CONTINUE WHEN (v_item->>'storage_path') IS NULL;

    UPDATE public.listing_media AS lm
       SET kind           = COALESCE(v_item->>'kind', lm.kind),
           is_main        = COALESCE((v_item->>'is_main')::boolean, false),
           ordering       = COALESCE((v_item->>'ordering')::int, lm.ordering),
           thumbnail_path = v_item->>'thumbnail_path'
     WHERE lm.listing_id = v_listing_id
       AND lm.storage_path = (v_item->>'storage_path');

    IF NOT FOUND THEN
      INSERT INTO public.listing_media (
        listing_id, kind, storage_path, external_url,
        ordering, is_main, watermarked, thumbnail_path
      )
      VALUES (
        v_listing_id,
        COALESCE(v_item->>'kind', 'image'),
        v_item->>'storage_path',
        NULL,
        COALESCE((v_item->>'ordering')::int, 0),
        COALESCE((v_item->>'is_main')::boolean, false),
        true,
        v_item->>'thumbnail_path'
      );
    END IF;
  END LOOP;

  -- --- 6e. Close the revision + audit. ------------------------------------
  UPDATE public.listing_revisions AS lr
     SET status = 'approved'
   WHERE lr.id = p_revision_id;

  INSERT INTO public.audit_logs (
    actor_user_id, action, target_type, target_id, before_state, after_state
  )
  VALUES (
    auth.uid(),
    'listing_revision.applied',
    'listing_revisions',
    p_revision_id::text,
    to_jsonb(v_rev),
    jsonb_build_object('listing_id', v_listing_id, 'status', 'approved')
  );
END;
$$;

REVOKE ALL ON FUNCTION public.apply_listing_revision(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apply_listing_revision(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.apply_listing_revision(UUID) TO authenticated;

-- ===========================================================================
-- 7. reject_listing_revision(p_revision_id, p_reason)
--    Admin (listings.review). Sets status='rejected' + reject_reason. The live
--    listing is untouched (stays approved on old content). Audited.
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.reject_listing_revision(
  p_revision_id UUID,
  p_reason      JSONB
)
RETURNS VOID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rev public.listing_revisions%ROWTYPE;
BEGIN
  IF NOT public.current_user_has_permission('listings.review') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'permission denied';
  END IF;

  SELECT lr.* INTO v_rev
  FROM public.listing_revisions AS lr
  WHERE lr.id = p_revision_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42704', MESSAGE = 'revision not found';
  END IF;

  IF v_rev.status <> 'pending_review' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'revision is not pending review';
  END IF;

  UPDATE public.listing_revisions AS lr
     SET status        = 'rejected',
         reject_reason = p_reason
   WHERE lr.id = p_revision_id;

  INSERT INTO public.audit_logs (
    actor_user_id, action, target_type, target_id, before_state, after_state
  )
  VALUES (
    auth.uid(),
    'listing_revision.rejected',
    'listing_revisions',
    p_revision_id::text,
    to_jsonb(v_rev),
    jsonb_build_object('status', 'rejected', 'reject_reason', p_reason)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.reject_listing_revision(UUID, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_listing_revision(UUID, JSONB) FROM anon;
GRANT EXECUTE ON FUNCTION public.reject_listing_revision(UUID, JSONB) TO authenticated;
