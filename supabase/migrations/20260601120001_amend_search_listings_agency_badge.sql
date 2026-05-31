-- Phase 19 follow-up (D-1): add the verified-agency badge fields to search_listings.
--
-- v_listings_public already projects agency_id / agency_name / agency_logo_path
-- (approved-only LEFT JOIN added in 20260531120006), but the search_listings RPC's
-- composite return type (search_result_row) omitted them, so search-result cards
-- had nothing to render and the verified badge appeared on the home feed +
-- listing details but NOT in search results (the documented D-1 gap). This
-- recreates the type + function with the three agency columns appended; the body
-- (params, WHERE, ORDER BY, cursor logic) is otherwise verbatim from
-- 20260525120003. Only search_listings depends on search_result_row, so the
-- drop is safe.

DROP FUNCTION IF EXISTS public.search_listings(
  text, text, text, uuid, uuid, uuid, numeric, numeric, numeric, numeric,
  integer, text, integer, text, numeric, numeric, text, timestamptz, uuid,
  numeric, uuid, integer);

DROP TYPE IF EXISTS public.search_result_row;

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
  published_at     timestamptz,
  agency_id        uuid,
  agency_name      text,
  agency_logo_path text
);

CREATE FUNCTION public.search_listings(
  p_query              text       DEFAULT NULL,
  p_purpose            text       DEFAULT NULL,
  p_property_type      text       DEFAULT NULL,
  p_governorate_id     uuid       DEFAULT NULL,
  p_city_id            uuid       DEFAULT NULL,
  p_area_id            uuid       DEFAULT NULL,
  p_price_min_usd      numeric    DEFAULT NULL,
  p_price_max_usd      numeric    DEFAULT NULL,
  p_price_min_syp      numeric    DEFAULT NULL,
  p_price_max_syp      numeric    DEFAULT NULL,
  p_rooms              integer    DEFAULT NULL,
  p_rooms_mode         text       DEFAULT 'exactly',
  p_bathrooms          integer    DEFAULT NULL,
  p_bathrooms_mode     text       DEFAULT 'exactly',
  p_area_size_min      numeric    DEFAULT NULL,
  p_area_size_max      numeric    DEFAULT NULL,
  p_sort               text       DEFAULT 'newest',
  p_cursor_published_at timestamptz DEFAULT NULL,
  p_cursor_id_newest   uuid       DEFAULT NULL,
  p_cursor_price_amount numeric   DEFAULT NULL,
  p_cursor_id_price    uuid       DEFAULT NULL,
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
    v.published_at,
    v.agency_id,
    v.agency_name,
    v.agency_logo_path
  FROM public.v_listings_public v
  LEFT JOIN public.listing_details ld ON ld.listing_id = v.id
  WHERE
    true
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
