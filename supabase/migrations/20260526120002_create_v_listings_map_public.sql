-- Phase 15 FR-001 + FR-002 + FR-003 + FR-004: public map dataset projection.
--
-- WHERE gates (privacy-critical invariant — defense in depth alongside RLS):
--   - l.status = 'approved' (Phase 12 approval gate)
--   - l.location_visibility IN ('exact', 'approximate') (FR-002 — never expose hidden / admin_only)
--   - (l.published_at IS NULL OR l.published_at <= now()) AND
--     (l.expires_at   IS NULL OR l.expires_at   >  now()) (publish-window)
--
-- Coordinate projection:
--   - exact      -> (l.latitude, l.longitude) verbatim (FR-004)
--   - approximate-> map_jitter_coordinates(...) (FR-003 — deterministic per-listing)
--
-- Field set (13 columns — FR-001 minimal projection):
--   id, title, marker_lat, marker_lng, is_approximate, location_visibility,
--   primary_amount, primary_currency, main_image_path, property_type, purpose,
--   governorate_name_ar, governorate_name_en.
--   (NO publisher contact details, NO description, NO full address — per FR-001 + ADR-0001.)
--
-- RLS posture:
--   WITH (security_invoker = true) ensures the view executes as the calling role,
--   so RLS on the underlying public.listings table is enforced (matches Phase 10's
--   v_publisher_listings pattern). The base table's listings_select_public policy
--   permits anon/authenticated reads when status='approved' AND publish-window —
--   the view's WHERE re-enforces the same gate (defense in depth) plus the
--   visibility-tier gate. GRANT SELECT explicitly to authenticated + anon makes
--   the public read intent explicit at the view layer.

CREATE OR REPLACE VIEW public.v_listings_map_public
WITH (security_invoker = true) AS
SELECT
  l.id,
  l.title,
  -- Marker coordinates: jitter for approximate, passthrough for exact.
  CASE l.location_visibility
    WHEN 'exact'       THEN l.latitude
    WHEN 'approximate' THEN jitter.jittered_lat
  END AS marker_lat,
  CASE l.location_visibility
    WHEN 'exact'       THEN l.longitude
    WHEN 'approximate' THEN jitter.jittered_lng
  END AS marker_lng,
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
LEFT JOIN LATERAL public.map_jitter_coordinates(
  l.id, l.area_id, l.latitude, l.longitude
) jitter ON l.location_visibility = 'approximate'
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
  -- Markerable-row guard: an approximate listing needs an area_id (the jitter
  -- function's area-centroid fallback requires it); an exact listing needs
  -- latitude+longitude. Rows that violate this invariant cannot render on a
  -- map and are excluded to keep the view robust against legacy/seed data
  -- that pre-dates Phase 10 R-12's auto-population guarantee.
  AND (
    (l.location_visibility = 'exact' AND l.latitude IS NOT NULL AND l.longitude IS NOT NULL)
    OR
    (l.location_visibility = 'approximate' AND l.area_id IS NOT NULL)
  );

GRANT SELECT ON public.v_listings_map_public TO authenticated, anon;

COMMENT ON VIEW public.v_listings_map_public IS
  'Phase 15 FR-001+FR-002+FR-003+FR-004: public map dataset. Returns one row per '
  'approved listing whose location_visibility is exact or approximate AND has the '
  'minimum required coordinate/area data to render. For approximate listings, '
  'coordinates are jittered server-side via map_jitter_coordinates() — the '
  'publishers true coords never appear in the wire response. Hidden, admin_only, '
  'and markerless listings are absent from this view.';
