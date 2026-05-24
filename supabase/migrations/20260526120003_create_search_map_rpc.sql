-- Phase 15 FR-007a: filter-shape-compatible RPC for the search -> map handoff.
-- Mirrors the parameter shape of Phase 14's search_listings RPC, minus
-- sort/cursor/limit (the map dataset is one-shot per FR-001a).
--
-- SCHEMA NOTE: data-model.md §3 references ld.rooms / ld.bathrooms / ld.area_size on
-- public.listing_details. The live schema (per 20260519120002 + 20260519120003) places
-- rooms, bathrooms, area_size on public.listings — only description / amenities /
-- year_built / furnished / parking live on listing_details. We adapt by reading those
-- three fields from public.listings, matching Phase 14's adaptation in
-- 20260525120003_create_search_listings_rpc.sql. The listing_details LEFT JOIN remains
-- solely for the description ILIKE keyword branch.

CREATE OR REPLACE FUNCTION public.search_map(
  -- Full-text keyword (null = no keyword filter)
  p_query              text       DEFAULT NULL,
  -- Facet filters (null = dimension inactive)
  p_purpose            text       DEFAULT NULL,
  p_property_type      text       DEFAULT NULL,
  p_governorate_id     uuid       DEFAULT NULL,
  p_city_id            uuid       DEFAULT NULL,
  p_area_id            uuid       DEFAULT NULL,
  -- Price range — pre-converted to USD and SYP by client per R-75
  p_price_min_usd      numeric    DEFAULT NULL,
  p_price_max_usd      numeric    DEFAULT NULL,
  p_price_min_syp      numeric    DEFAULT NULL,
  p_price_max_syp      numeric    DEFAULT NULL,
  -- Rooms filter
  p_rooms              integer    DEFAULT NULL,
  p_rooms_mode         text       DEFAULT 'exactly',
  -- Bathrooms filter
  p_bathrooms          integer    DEFAULT NULL,
  p_bathrooms_mode     text       DEFAULT 'exactly',
  -- Area size range
  p_area_size_min      numeric    DEFAULT NULL,
  p_area_size_max      numeric    DEFAULT NULL
)
RETURNS SETOF public.v_listings_map_public
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT v.*
  FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  LEFT JOIN public.listing_details ld ON ld.listing_id = l.id
  LEFT JOIN public.listing_prices lp_usd
    ON lp_usd.listing_id = l.id AND lp_usd.currency_code = 'USD'
  LEFT JOIN public.listing_prices lp_syp
    ON lp_syp.listing_id = l.id AND lp_syp.currency_code = 'SYP'
  WHERE
    -- Keyword (Phase 14 tsvector + ILIKE supplement pattern; null/empty = no filter)
    (p_query IS NULL OR p_query = ''
     OR l.search_vector @@ plainto_tsquery('simple', p_query)
     OR ld.description ILIKE '%' || p_query || '%')
    -- Facets
    AND (p_purpose         IS NULL OR l.purpose         = p_purpose)
    AND (p_property_type   IS NULL OR l.property_type   = p_property_type)
    AND (p_governorate_id  IS NULL OR l.governorate_id  = p_governorate_id)
    AND (p_city_id         IS NULL OR l.city_id         = p_city_id)
    AND (p_area_id         IS NULL OR l.area_id         = p_area_id)
    -- Price range — match if EITHER USD or SYP row falls within bounds
    AND (
      (p_price_min_usd IS NULL AND p_price_max_usd IS NULL
       AND p_price_min_syp IS NULL AND p_price_max_syp IS NULL)
      OR (lp_usd.amount IS NOT NULL
          AND (p_price_min_usd IS NULL OR lp_usd.amount >= p_price_min_usd)
          AND (p_price_max_usd IS NULL OR lp_usd.amount <= p_price_max_usd))
      OR (lp_syp.amount IS NOT NULL
          AND (p_price_min_syp IS NULL OR lp_syp.amount >= p_price_min_syp)
          AND (p_price_max_syp IS NULL OR lp_syp.amount <= p_price_max_syp))
    )
    -- Rooms (exactly / at_least) — column lives on public.listings (schema note above)
    AND (
      p_rooms IS NULL
      OR (p_rooms_mode = 'exactly'  AND l.rooms = p_rooms)
      OR (p_rooms_mode = 'at_least' AND l.rooms >= p_rooms)
    )
    -- Bathrooms (exactly / at_least)
    AND (
      p_bathrooms IS NULL
      OR (p_bathrooms_mode = 'exactly'  AND l.bathrooms = p_bathrooms)
      OR (p_bathrooms_mode = 'at_least' AND l.bathrooms >= p_bathrooms)
    )
    -- Area size range
    AND (p_area_size_min IS NULL OR l.area_size >= p_area_size_min)
    AND (p_area_size_max IS NULL OR l.area_size <= p_area_size_max);
$$;

REVOKE ALL ON FUNCTION public.search_map(
  text, text, text, uuid, uuid, uuid,
  numeric, numeric, numeric, numeric,
  integer, text, integer, text, numeric, numeric
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_map(
  text, text, text, uuid, uuid, uuid,
  numeric, numeric, numeric, numeric,
  integer, text, integer, text, numeric, numeric
) TO authenticated, anon;

COMMENT ON FUNCTION public.search_map(
  text, text, text, uuid, uuid, uuid,
  numeric, numeric, numeric, numeric,
  integer, text, integer, text, numeric, numeric
) IS
  'Phase 15 FR-007a: filter-shape-compatible RPC for the search -> map handoff. '
  'Mirrors search_listings parameter shape minus sort/cursor/limit (map dataset is one-shot). '
  'Returns SETOF v_listings_map_public — visibility + approval gates compose at the view layer.';
