-- 20260901120001_gate_listing_coordinates
--
-- SEC-I1 residual (docs/qa/e2e-2026-07-16/SECURITY_AUDIT.md) — STEP 1 of 2.
--
-- APPLY ORDER (important):
--   1. THIS migration                                  — additive, backward compatible.
--   2. ship the app build from this same commit        — clients stop reading the raw columns.
--   3. 20260901120002_revoke_authenticated_listing_coordinates.sql — the actual REVOKE.
-- Applying …120002 before an updated client is deployed WILL break the listing
-- edit form, the admin revision diff and the admin preview (they still select
-- `*`). This file alone changes no privilege and no client-visible behaviour, so
-- it is safe to apply on its own and leave …120002 for a later window.
--
-- FINDING: `20260717120007` revoked `latitude`/`longitude` from `anon` only.
-- `authenticated` still holds a TABLE-WIDE SELECT on public.listings, so any
-- signed-up user can hand-craft
--     GET /rest/v1/listings?select=id,latitude,longitude&status=eq.approved
-- and read every listing's EXACT pin, defeating the `approximate`
-- location-visibility jitter for 100% of listings.
--
-- WHY THE BARE REVOKE IS NOT ENOUGH — the blocker the audit's fix plan missed:
-- BOTH `v_listings_map_public` and `v_publisher_listings` are
-- `security_invoker = true` views that reference `l.latitude` / `l.longitude`.
-- A security_invoker view checks the UNDERLYING table's column privileges
-- against the CALLER, so a column-level revoke makes every read of those views
-- fail with `permission denied for table listings` — i.e. it takes out the map,
-- the listing-detail marker and "My Listings".
--   ⚠ This is not hypothetical: `20260717120007` already revoked the columns
--     from `anon`, so `v_listings_map_public` is very probably ALREADY broken
--     for signed-out visitors on the live database (guest map + guest
--     listing-detail marker). This migration fixes that regression too — please
--     re-check the guest map right after applying.
--
-- THE FIX, in three parts:
--   (a) `listing_marker_coordinates(listing_id)` — a SECURITY DEFINER function
--       that owns the raw-column read and returns only the PUBLIC-GATED marker
--       (exact → verbatim, approximate → jittered, hidden/admin_only → no row).
--       `v_listings_map_public` is rebuilt on top of it, so the view no longer
--       references the raw columns at all and stays security_invoker (RLS still
--       enforced, Supabase advisor 0010 still clean).
--   (b) `get_listing_coordinates(listing_id)` — the owner/admin RPC from the
--       audit's fix plan, for the edit form / revision diff / admin preview.
--   (c) `v_publisher_listings` is rebuilt WITHOUT the two coordinate columns
--       (no client reads them — "My Listings" is a list screen, and the edit
--       form loads coordinates through (b)).
--
-- No `anon` grant is added by (b); (a) keeps the anon grant the map already
-- needs, and enforces the same approved+publish-window+visibility gate the view
-- does, so calling it directly leaks nothing the map view would not already show.

-- ─── (a) Public marker coordinates ─────────────────────────────────────────
-- Volatility is deliberately left at the default (VOLATILE) to match
-- public.map_jitter_coordinates, which this delegates to — the planner then
-- treats the rebuilt view exactly as it treated the old one.
CREATE OR REPLACE FUNCTION public.listing_marker_coordinates(p_listing_id uuid)
RETURNS TABLE(marker_lat numeric, marker_lng numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_visibility text;
  v_lat        numeric;
  v_lng        numeric;
  v_area_id    uuid;
BEGIN
  -- Table alias `l` is mandatory: the OUT parameters would otherwise be
  -- ambiguous against same-named columns (project gotcha
  -- `project_supabase_view_rls_gotchas`). Belt-and-braces here since the OUT
  -- names differ, but keep the habit.
  SELECT l.location_visibility, l.latitude, l.longitude, l.area_id
    INTO v_visibility, v_lat, v_lng, v_area_id
  FROM public.listings AS l
  WHERE l.id = p_listing_id
    -- Same public gate as v_listings_map_public's WHERE (FR-002) so a direct
    -- call can never reveal a draft/paused/expired listing's pin.
    AND l.status = 'approved'
    AND (l.published_at IS NULL OR l.published_at <= now())
    AND (l.expires_at   IS NULL OR l.expires_at   >  now());

  IF NOT FOUND THEN
    RETURN;  -- not publicly visible → no marker
  END IF;

  IF v_visibility = 'exact' THEN
    IF v_lat IS NULL OR v_lng IS NULL THEN
      RETURN;  -- markerless row (legacy/seed data) — same guard as the old view
    END IF;
    marker_lat := v_lat;
    marker_lng := v_lng;
    RETURN NEXT;
    RETURN;
  END IF;

  IF v_visibility = 'approximate' THEN
    -- map_jitter_coordinates RAISES when the area has no centroid; the old view
    -- relied on its WHERE to keep such rows away from the call. Pre-check here
    -- so a malformed row is excluded instead of failing the whole query.
    IF v_area_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.areas AS a
      WHERE a.id = v_area_id
        AND a.centroid_lat IS NOT NULL
        AND a.centroid_lng IS NOT NULL
    ) THEN
      RETURN;
    END IF;
    SELECT j.jittered_lat, j.jittered_lng
      INTO marker_lat, marker_lng
    FROM public.map_jitter_coordinates(p_listing_id, v_area_id, v_lat, v_lng) AS j;
    IF marker_lat IS NULL OR marker_lng IS NULL THEN
      RETURN;
    END IF;
    RETURN NEXT;
    RETURN;
  END IF;

  -- 'hidden' / 'admin_only' → never any coordinate.
  RETURN;
END;
$$;

REVOKE ALL ON FUNCTION public.listing_marker_coordinates(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.listing_marker_coordinates(uuid) TO anon, authenticated;

COMMENT ON FUNCTION public.listing_marker_coordinates(uuid) IS
  'SEC-I1: the ONLY public path to a listing marker. Returns the visibility-gated '
  'coordinate pair (exact verbatim / approximate jittered / nothing for hidden + '
  'admin_only) for approved, in-window listings, and no row otherwise. Owns the raw '
  'latitude/longitude read so v_listings_map_public can stay security_invoker after '
  'the columns are revoked from anon + authenticated.';

-- ─── (a2) Rebuild v_listings_map_public on top of the function ─────────────
-- Body is 20260526120002's verbatim, EXCEPT: the two CASE expressions and the
-- markerable-row guard now come from listing_marker_coordinates(), and the
-- jitter LATERAL is gone (folded into the function). Column names, order and
-- types are unchanged, so CREATE OR REPLACE succeeds and
-- `search_map() RETURNS SETOF public.v_listings_map_public` keeps working.
CREATE OR REPLACE VIEW public.v_listings_map_public
WITH (security_invoker = true) AS
SELECT
  l.id,
  l.title,
  marker.marker_lat,
  marker.marker_lng,
  (l.location_visibility = 'approximate') AS is_approximate,
  l.location_visibility,
  -- Primary price (is_primary = true row).
  lp.amount        AS primary_amount,
  lp.currency_code AS primary_currency,
  -- Main image (lowest ordering value among image-kind rows).
  lm.storage_path  AS main_image_path,
  -- Property classification.
  l.property_type,
  l.purpose,
  -- Bilingual governorate names (only governorate-level for the popover; city
  -- omitted to keep the surface minimal per FR-001).
  g.display_name->>'ar' AS governorate_name_ar,
  g.display_name->>'en' AS governorate_name_en
FROM public.listings l
LEFT JOIN LATERAL public.listing_marker_coordinates(l.id) marker ON true
LEFT JOIN LATERAL (
  SELECT amount, currency_code
  FROM public.listing_prices
  WHERE listing_id = l.id
    AND is_primary = true
  LIMIT 1
) lp ON true
LEFT JOIN LATERAL (
  SELECT storage_path
  FROM public.listing_media
  WHERE listing_id = l.id
    AND kind = 'image'
  ORDER BY ordering ASC
  LIMIT 1
) lm ON true
LEFT JOIN public.governorates g ON g.id = l.governorate_id
WHERE l.status = 'approved'
  AND l.location_visibility IN ('exact', 'approximate')
  AND (l.published_at IS NULL OR l.published_at <= now())
  AND (l.expires_at   IS NULL OR l.expires_at   >  now())
  -- Markerable-row guard (was: exact needs lat+lng, approximate needs area_id).
  -- listing_marker_coordinates() applies exactly those rules and returns no row
  -- when they are not met, so a NULL marker means "cannot render on a map".
  AND marker.marker_lat IS NOT NULL
  AND marker.marker_lng IS NOT NULL;

GRANT SELECT ON public.v_listings_map_public TO authenticated, anon;
-- Mirror 20260717120001 (SEC-H1): clients never write through a view.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.v_listings_map_public FROM anon, authenticated;

COMMENT ON VIEW public.v_listings_map_public IS
  'Phase 15 FR-001+FR-002+FR-003+FR-004: public map dataset. Returns one row per '
  'approved listing whose location_visibility is exact or approximate AND has the '
  'minimum required coordinate/area data to render. Coordinates come exclusively '
  'from public.listing_marker_coordinates() (SECURITY DEFINER) — for approximate '
  'listings they are jittered server-side, and the publishers true coords never '
  'appear in the wire response. The view itself no longer references '
  'listings.latitude/longitude, so it survives the SEC-I1 column revoke while '
  'staying security_invoker. Hidden, admin_only and markerless listings are absent.';

-- ─── (b) Owner/admin exact-coordinate RPC ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_listing_coordinates(p_listing_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner uuid;
  v_lat   numeric;
  v_lng   numeric;
  v_uid   uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN NULL;  -- never serve coordinates to an unauthenticated caller
  END IF;

  SELECT l.publisher_user_id, l.latitude, l.longitude
    INTO v_owner, v_lat, v_lng
  FROM public.listings AS l
  WHERE l.id = p_listing_id;

  -- Uniform NULL for "no such listing" AND "not yours": no existence oracle.
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  IF v_owner IS DISTINCT FROM v_uid
     AND NOT public.current_user_has_permission('listings.view_all') THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object('latitude', v_lat, 'longitude', v_lng);
END;
$$;

REVOKE ALL ON FUNCTION public.get_listing_coordinates(uuid) FROM PUBLIC;
-- authenticated ONLY — deliberately no anon grant (a guest has no listing to own
-- and no moderation permission, so it could only ever return NULL for them).
GRANT EXECUTE ON FUNCTION public.get_listing_coordinates(uuid) TO authenticated;

COMMENT ON FUNCTION public.get_listing_coordinates(uuid) IS
  'SEC-I1: returns {"latitude":…,"longitude":…} for a listing the caller OWNS or can '
  'moderate (listings.view_all), else NULL — the same NULL a missing listing returns, '
  'so it is not an existence oracle. Replaces the direct latitude/longitude SELECT in '
  'the listing edit form, the admin revision diff and the admin listing preview.';

-- ─── (c) v_publisher_listings without the coordinate columns ───────────────
-- DROP + CREATE (CREATE OR REPLACE VIEW cannot remove columns). Nothing depends
-- on this view — verified across supabase/migrations: only the create,
-- 20260519120009 (security_invoker + grants) and 20260717120001 (write revoke)
-- reference it, and no function returns SETOF it. Grants are re-applied below
-- because DROP discards them.
DROP VIEW IF EXISTS public.v_publisher_listings;

CREATE VIEW public.v_publisher_listings
WITH (security_invoker = true) AS
SELECT
  l.id                       AS listing_id,
  l.publisher_user_id,
  l.agency_id,
  l.purpose,
  l.property_type,
  l.status,
  l.title,
  l.governorate_id,
  l.city_id,
  l.area_id,
  l.address_text,
  -- SEC-I1: l.latitude / l.longitude removed. No client reads them from this
  -- view (My Listings is a list screen); the edit form fetches the owner's own
  -- coordinates through public.get_listing_coordinates().
  l.location_visibility,
  l.phone,
  l.whatsapp,
  l.contact_name_visibility,
  l.area_size,
  l.rooms,
  l.bathrooms,
  l.floor,
  l.created_at,
  l.updated_at,
  l.published_at,
  l.expires_at,
  h.id                       AS latest_history_id,
  h.previous_status          AS latest_history_previous_status,
  h.new_status               AS latest_history_new_status,
  h.changed_by               AS latest_history_changed_by,
  h.changed_at               AS latest_history_changed_at,
  h.reason                   AS latest_history_reason,
  p.id                       AS primary_price_id,
  p.currency_code            AS primary_price_currency_code,
  p.amount                   AS primary_price_amount
FROM public.listings l
LEFT JOIN LATERAL (
  SELECT * FROM public.listing_status_history
  WHERE listing_id = l.id
  ORDER BY changed_at DESC
  LIMIT 1
) h ON true
LEFT JOIN public.listing_prices p
  ON p.listing_id = l.id AND p.is_primary = true
WHERE l.status <> 'deleted';

REVOKE ALL ON TABLE public.v_publisher_listings FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.v_publisher_listings TO authenticated;

COMMENT ON VIEW public.v_publisher_listings IS
  'Phase 10 FR-015/SC-015 query helper (security_invoker — underlying RLS is the '
  'security boundary). SEC-I1: latitude/longitude are no longer projected; owner '
  'coordinate reads go through public.get_listing_coordinates().';
