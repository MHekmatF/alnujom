-- Phase 14: SECURITY DEFINER search RPC.
-- Re-enforces status='approved' + publish-window guard independently of RLS (R-74)
-- via the v_listings_public view filter (defense-in-depth).
-- Full parameter contract: contracts/phase14-search-listings-rpc.md
--
-- SCHEMA NOTE: data-model.md §1.3 references ld.rooms / ld.bathrooms / ld.area_size
-- on public.listing_details. The live schema (per migration 20260519120002 +
-- 20260519120003) places rooms, bathrooms, area_size on public.listings — only
-- description, amenities, year_built, furnished, parking live on listing_details.
-- We adapt by reading rooms/bathrooms/area_size from v_listings_public (projected
-- from l.rooms / l.bathrooms / l.area_size in the view) and keeping the LEFT JOIN
-- on listing_details solely for the description ILIKE keyword branch.

-- Return type composite (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'search_result_row'
  ) THEN
    CREATE TYPE public.search_result_row AS (
      id               uuid,
      title            text,
      property_type    text,
      purpose          text,
      governorate_name_ar text,
      governorate_name_en text,
      city_name_ar     text,
      city_name_en     text,
      primary_amount   numeric,
      primary_currency text,
      main_image_path  text,
      published_at     timestamptz
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.search_listings(
  -- Full-text keyword (null = no keyword filter)
  p_query              text       DEFAULT NULL,
  -- Facet filters (null = dimension inactive)
  p_purpose            text       DEFAULT NULL,
  p_property_type      text       DEFAULT NULL,
  p_governorate_id     uuid       DEFAULT NULL,
  p_city_id            uuid       DEFAULT NULL,
  p_area_id            uuid       DEFAULT NULL,
  -- Price range — pre-converted to USD and SYP by client (R-75)
  p_price_min_usd      numeric    DEFAULT NULL,
  p_price_max_usd      numeric    DEFAULT NULL,
  p_price_min_syp      numeric    DEFAULT NULL,
  p_price_max_syp      numeric    DEFAULT NULL,
  -- Rooms filter
  p_rooms              integer    DEFAULT NULL,
  p_rooms_mode         text       DEFAULT 'exactly',  -- 'exactly' | 'at_least'
  -- Bathrooms filter
  p_bathrooms          integer    DEFAULT NULL,
  p_bathrooms_mode     text       DEFAULT 'exactly',  -- 'exactly' | 'at_least'
  -- Area size range (m²)
  p_area_size_min      numeric    DEFAULT NULL,
  p_area_size_max      numeric    DEFAULT NULL,
  -- Sort order
  p_sort               text       DEFAULT 'newest',   -- 'newest' | 'price_asc' | 'price_desc'
  -- Cursor (newest sort)
  p_cursor_published_at timestamptz DEFAULT NULL,
  p_cursor_id_newest   uuid       DEFAULT NULL,
  -- Cursor (price sorts)
  p_cursor_price_amount numeric   DEFAULT NULL,
  p_cursor_id_price    uuid       DEFAULT NULL,
  -- Page size
  p_limit              integer    DEFAULT 20
)
RETURNS SETOF public.search_result_row
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    v.id,
    v.title,
    v.property_type,
    v.purpose,
    v.governorate_name_ar,
    v.governorate_name_en,
    v.city_name_ar,
    v.city_name_en,
    v.primary_amount,
    v.primary_currency,
    v.main_image_path,
    v.published_at
  FROM public.v_listings_public v
  LEFT JOIN public.listing_details ld ON ld.listing_id = v.id
  WHERE
    -- Approved + window guard is already enforced by the view (defense in depth)
    true
    -- Keyword: full-text on title/address + ILIKE on description
    AND (
      p_query IS NULL
      OR v.search_vector @@ plainto_tsquery('simple', p_query)
      OR ld.description ILIKE '%' || p_query || '%'
    )
    -- Facet filters
    AND (p_purpose       IS NULL OR v.purpose       = p_purpose)
    AND (p_property_type IS NULL OR v.property_type = p_property_type)
    AND (p_governorate_id IS NULL OR v.governorate_id = p_governorate_id)
    AND (p_city_id        IS NULL OR v.city_id        = p_city_id)
    AND (p_area_id        IS NULL OR v.area_id        = p_area_id)
    -- Price range (compare against listing's native currency; client pre-converts bounds)
    AND (
      p_price_min_usd IS NULL OR p_price_max_usd IS NULL
      OR (v.primary_currency = 'USD' AND v.primary_amount BETWEEN p_price_min_usd AND p_price_max_usd)
      OR (v.primary_currency = 'SYP' AND v.primary_amount BETWEEN p_price_min_syp AND p_price_max_syp)
    )
    -- Rooms filter
    AND (
      p_rooms IS NULL
      OR (p_rooms_mode = 'exactly'  AND v.rooms = p_rooms)
      OR (p_rooms_mode = 'at_least' AND v.rooms >= p_rooms)
    )
    -- Bathrooms filter
    AND (
      p_bathrooms IS NULL
      OR (p_bathrooms_mode = 'exactly'  AND v.bathrooms = p_bathrooms)
      OR (p_bathrooms_mode = 'at_least' AND v.bathrooms >= p_bathrooms)
    )
    -- Area size range
    AND (p_area_size_min IS NULL OR v.area_size >= p_area_size_min)
    AND (p_area_size_max IS NULL OR v.area_size <= p_area_size_max)
    -- Cursor predicates
    AND (
      p_sort <> 'newest'
      OR p_cursor_published_at IS NULL
      OR (v.published_at, v.id) < (p_cursor_published_at, p_cursor_id_newest)
    )
    AND (
      p_sort NOT IN ('price_asc', 'price_desc')
      OR p_cursor_price_amount IS NULL
      OR (
        p_sort = 'price_asc'
        AND (v.primary_amount, v.id::text) > (p_cursor_price_amount, p_cursor_id_price::text)
      )
      OR (
        p_sort = 'price_desc'
        AND (v.primary_amount, v.id::text) < (p_cursor_price_amount, p_cursor_id_price::text)
      )
    )
  ORDER BY
    CASE p_sort
      WHEN 'newest'     THEN v.published_at END DESC,
    CASE p_sort
      WHEN 'price_asc'  THEN v.primary_amount END ASC,
    CASE p_sort
      WHEN 'price_desc' THEN v.primary_amount END DESC,
    v.id ASC
  LIMIT p_limit;
END;
$$;

-- Grant execute to authenticated and anon roles
GRANT EXECUTE ON FUNCTION public.search_listings TO authenticated, anon;
