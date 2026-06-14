-- Phase 031 (WS-D) — amenity / furnished / parking filters on search_listings.
--
-- Adds three NULL-safe predicates so the smart-search assistant AND the manual
-- filter sheet can narrow by listing features:
--   • p_furnished  (boolean)  → (p_furnished IS NULL OR ld.furnished = p_furnished)
--   • p_parking    (boolean)  → (p_parking   IS NULL OR ld.parking   = p_parking)
--   • p_amenities  (jsonb)    → (p_amenities IS NULL OR ld.amenities @> p_amenities)
--
-- SCHEMA NOTE: furnished/parking/amenities live on public.listing_details (ld),
-- amenities is a JSONB array. The RPC already LEFT JOINs listing_details.
-- Containment (@>) = "every requested amenity present". A LEFT-JOIN NULL ld is
-- excluded when a feature filter is set, included when it is NULL (unfiltered).
--
-- IMPORTANT: this is rebuilt on top of the LIVE definition, which already
-- carries p_is_agency (Phase 026 owner/agent filter, the 23rd param). The three
-- new params are appended AFTER it (params are passed by NAME from the Dart
-- datasource, so order is immaterial to callers; every existing call keeps
-- working with the new params defaulting to NULL = unfiltered). The return type
-- (search_result_row) and all cursor/ORDER BY logic are verbatim from the live
-- function. DROP targets the exact live 23-arg signature so no stale overload
-- is left behind.

DROP FUNCTION IF EXISTS public.search_listings(
  text, text, text, uuid, uuid, uuid, numeric, numeric, numeric, numeric,
  integer, text, integer, text, numeric, numeric, text, timestamptz, uuid,
  numeric, uuid, integer, boolean);

CREATE OR REPLACE FUNCTION public.search_listings(
  p_query               text        DEFAULT NULL,
  p_purpose             text        DEFAULT NULL,
  p_property_type       text        DEFAULT NULL,
  p_governorate_id      uuid        DEFAULT NULL,
  p_city_id             uuid        DEFAULT NULL,
  p_area_id             uuid        DEFAULT NULL,
  p_price_min_usd       numeric     DEFAULT NULL,
  p_price_max_usd       numeric     DEFAULT NULL,
  p_price_min_syp       numeric     DEFAULT NULL,
  p_price_max_syp       numeric     DEFAULT NULL,
  p_rooms               integer     DEFAULT NULL,
  p_rooms_mode          text        DEFAULT 'exactly',
  p_bathrooms           integer     DEFAULT NULL,
  p_bathrooms_mode      text        DEFAULT 'exactly',
  p_area_size_min       numeric     DEFAULT NULL,
  p_area_size_max       numeric     DEFAULT NULL,
  p_sort                text        DEFAULT 'newest',
  p_cursor_published_at timestamptz DEFAULT NULL,
  p_cursor_id_newest    uuid        DEFAULT NULL,
  p_cursor_price_amount numeric     DEFAULT NULL,
  p_cursor_id_price     uuid        DEFAULT NULL,
  p_limit               integer     DEFAULT 20,
  p_is_agency           boolean     DEFAULT NULL,
  -- Phase 031 (WS-D) — feature filters, appended for backward compatibility.
  p_furnished           boolean     DEFAULT NULL,
  p_parking             boolean     DEFAULT NULL,
  p_amenities           jsonb       DEFAULT NULL
)
RETURNS SETOF public.search_result_row
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    v.id, v.title, v.property_type, v.purpose,
    v.governorate_name_ar, v.governorate_name_en,
    v.city_name_ar, v.city_name_en,
    v.primary_amount, v.primary_currency, v.main_image_path, v.published_at,
    v.agency_id, v.agency_name, v.agency_logo_path
  FROM public.v_listings_public v
  LEFT JOIN public.listing_details ld ON ld.listing_id = v.id
  WHERE
    true
    AND (p_is_agency IS NULL OR (v.agency_id IS NOT NULL) = p_is_agency)
    AND (
      p_query IS NULL
      OR v.search_vector @@ plainto_tsquery('simple', p_query)
      OR ld.description ILIKE '%' || p_query || '%'
    )
    AND (p_purpose       IS NULL OR v.purpose       = p_purpose)
    AND (p_property_type IS NULL OR v.property_type = p_property_type)
    AND (p_governorate_id IS NULL OR v.governorate_id = p_governorate_id)
    AND (p_city_id        IS NULL OR v.city_id        = p_city_id)
    AND (p_area_id        IS NULL OR v.area_id        = p_area_id)
    AND (
      (v.primary_currency = 'USD' AND (
        p_price_min_usd IS NULL OR p_price_max_usd IS NULL
        OR v.primary_amount BETWEEN p_price_min_usd AND p_price_max_usd
      ))
      OR (v.primary_currency = 'SYP' AND (
        p_price_min_syp IS NULL OR p_price_max_syp IS NULL
        OR v.primary_amount BETWEEN p_price_min_syp AND p_price_max_syp
      ))
    )
    AND (
      p_rooms IS NULL
      OR (p_rooms_mode = 'exactly'  AND v.rooms = p_rooms)
      OR (p_rooms_mode = 'at_least' AND v.rooms >= p_rooms)
    )
    AND (
      p_bathrooms IS NULL
      OR (p_bathrooms_mode = 'exactly'  AND v.bathrooms = p_bathrooms)
      OR (p_bathrooms_mode = 'at_least' AND v.bathrooms >= p_bathrooms)
    )
    AND (p_area_size_min IS NULL OR v.area_size >= p_area_size_min)
    AND (p_area_size_max IS NULL OR v.area_size <= p_area_size_max)
    -- Phase 031 (WS-D) — feature filters (NULL-safe; ld is a LEFT JOIN so a
    -- listing missing its details row is excluded when a feature filter is set).
    AND (p_furnished IS NULL OR ld.furnished = p_furnished)
    AND (p_parking   IS NULL OR ld.parking   = p_parking)
    AND (p_amenities IS NULL OR ld.amenities @> p_amenities)
    AND (
      p_sort <> 'newest'
      OR p_cursor_published_at IS NULL
      OR (v.published_at < p_cursor_published_at)
      OR (v.published_at = p_cursor_published_at AND v.id > p_cursor_id_newest)
    )
    AND (
      p_sort NOT IN ('price_asc', 'price_desc')
      OR p_cursor_price_amount IS NULL
      OR (
        p_sort = 'price_asc'
        AND (
          (v.primary_amount > p_cursor_price_amount)
          OR (v.primary_amount = p_cursor_price_amount AND v.id > p_cursor_id_price)
        )
      )
      OR (
        p_sort = 'price_desc'
        AND (
          (v.primary_amount < p_cursor_price_amount)
          OR (v.primary_amount = p_cursor_price_amount AND v.id > p_cursor_id_price)
        )
      )
    )
  ORDER BY
    CASE p_sort WHEN 'newest'     THEN v.published_at   END DESC NULLS LAST,
    CASE p_sort WHEN 'price_asc'  THEN v.primary_amount END ASC  NULLS LAST,
    CASE p_sort WHEN 'price_desc' THEN v.primary_amount END DESC NULLS LAST,
    v.id ASC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_listings TO authenticated, anon;
