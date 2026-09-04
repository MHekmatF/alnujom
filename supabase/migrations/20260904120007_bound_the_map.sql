-- 20260904120007_bound_the_map.sql
--
-- Plan A17 / review §4 C1 — the map returned EVERY approved listing.
--
-- `search_map` had no LIMIT and no bounding box, and the unfiltered path did not
-- even go through it (the client read `v_listings_map_public` whole). At 5,000
-- approved listings that is a ~1 MB payload downloaded, parsed and turned into
-- 5,000 marker widgets on every map open, on Syrian mobile data.
--
-- This adds a viewport box and a hard cap. The client sends the visible bounds
-- and re-asks as the camera moves; both the filtered and the unfiltered path now
-- go through this one function, so the cap cannot be bypassed by reading the
-- view directly (the client no longer does).
--
-- WHAT THE BOX IS MEASURED AGAINST
-- --------------------------------
-- `v.marker_lat` / `v.marker_lng` — the PUBLISHED coordinates, which for an
-- `approximate` listing are the area-centroid jitter, not the property. Never
-- `listings.latitude/longitude`: filtering on the true position would turn this
-- function into the exact oracle `20260902120002_seal_map_jitter_oracle.sql`
-- closed (shrink the box, ask again, and the jitter is undone). Measuring the
-- box against what the user can already see on screen tells them nothing new.
--
-- WHAT THIS DOES NOT FIX
-- ----------------------
-- The box cuts the PAYLOAD, not the scan: `marker_lat` is computed per row by
-- `listing_marker_coordinates()` in the view's LATERAL, so the rows are still
-- visited before they can be excluded. Measured on today's data, a Damascus box
-- costs 15.0 ms / 2174 buffers against 15.5 ms / 2216 unbounded — the same work,
-- for 6.3 KB on the wire instead of 10.1 KB. (`EXPLAIN` cannot see inside
-- either: Postgres never inlines a SECURITY DEFINER SQL function, so the call
-- shows up as one opaque `Function Scan`.)
--
-- Cheap today at 51 listings, and cheap for a long while. If the scan itself
-- ever becomes the cost, the fix is a coarse pre-filter below the LATERAL —
-- `listings.latitude/longitude` for `exact` rows and `areas.centroid_*` padded
-- by the jitter radius for `approximate` ones, both provably wider than the
-- exact test above, so the result set is unchanged.
--
-- Adding parameters is not a replace — it would leave the old 16-argument
-- function in place as an overload and PostgREST would not know which to call.
-- The old signature is dropped explicitly.

DROP FUNCTION IF EXISTS public.search_map(
  text, text, text, uuid, uuid, uuid,
  numeric, numeric, numeric, numeric,
  integer, text, integer, text,
  numeric, numeric
);

CREATE FUNCTION public.search_map(
  p_query           text    DEFAULT NULL,
  p_purpose         text    DEFAULT NULL,
  p_property_type   text    DEFAULT NULL,
  p_governorate_id  uuid    DEFAULT NULL,
  p_city_id         uuid    DEFAULT NULL,
  p_area_id         uuid    DEFAULT NULL,
  p_price_min_usd   numeric DEFAULT NULL,
  p_price_max_usd   numeric DEFAULT NULL,
  p_price_min_syp   numeric DEFAULT NULL,
  p_price_max_syp   numeric DEFAULT NULL,
  p_rooms           integer DEFAULT NULL,
  p_rooms_mode      text    DEFAULT 'exactly',
  p_bathrooms       integer DEFAULT NULL,
  p_bathrooms_mode  text    DEFAULT 'exactly',
  p_area_size_min   numeric DEFAULT NULL,
  p_area_size_max   numeric DEFAULT NULL,
  -- Plan A17. All four NULL (an older build, or a camera that has not settled
  -- yet) means unbounded — still capped by the LIMIT below.
  p_min_lat         numeric DEFAULT NULL,
  p_max_lat         numeric DEFAULT NULL,
  p_min_lng         numeric DEFAULT NULL,
  p_max_lng         numeric DEFAULT NULL
)
RETURNS SETOF public.v_listings_map_public
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT v.*
  FROM public.v_listings_map_public v
  JOIN public.listings l ON l.id = v.id
  LEFT JOIN public.listing_details ld ON ld.listing_id = l.id
  LEFT JOIN public.listing_prices lp_usd
    ON lp_usd.listing_id = l.id AND lp_usd.currency_code = 'USD'
  LEFT JOIN public.listing_prices lp_syp
    ON lp_syp.listing_id = l.id AND lp_syp.currency_code = 'SYP'
  WHERE
    (p_query IS NULL OR p_query = ''
     OR l.search_vector @@ plainto_tsquery('simple', p_query)
     OR ld.description ILIKE '%' || p_query || '%')
    AND (p_purpose         IS NULL OR l.purpose         = p_purpose)
    AND (p_property_type   IS NULL OR l.property_type   = p_property_type)
    AND (p_governorate_id  IS NULL OR l.governorate_id  = p_governorate_id)
    AND (p_city_id         IS NULL OR l.city_id         = p_city_id)
    AND (p_area_id         IS NULL OR l.area_id         = p_area_id)
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
    AND (
      p_rooms IS NULL
      OR (p_rooms_mode = 'exactly'  AND l.rooms = p_rooms)
      OR (p_rooms_mode = 'at_least' AND l.rooms >= p_rooms)
    )
    AND (
      p_bathrooms IS NULL
      OR (p_bathrooms_mode = 'exactly'  AND l.bathrooms = p_bathrooms)
      OR (p_bathrooms_mode = 'at_least' AND l.bathrooms >= p_bathrooms)
    )
    AND (p_area_size_min IS NULL OR l.area_size >= p_area_size_min)
    AND (p_area_size_max IS NULL OR l.area_size <= p_area_size_max)
    -- Plan A17 — the viewport, against the PUBLISHED marker (see the header).
    -- Each edge is independent so a half-specified box still narrows.
    AND (p_min_lat IS NULL OR v.marker_lat >= p_min_lat)
    AND (p_max_lat IS NULL OR v.marker_lat <= p_max_lat)
    AND (p_min_lng IS NULL OR v.marker_lng >= p_min_lng)
    AND (p_max_lng IS NULL OR v.marker_lng <= p_max_lng)
  -- Newest first, so a viewport holding more than the cap keeps the freshest
  -- listings rather than an arbitrary 500. `id` breaks ties so paging the
  -- camera around does not shuffle markers between identical timestamps.
  ORDER BY l.published_at DESC NULLS LAST, l.id
  LIMIT 500;
$function$;

-- The map is guest-reachable, so anon keeps EXECUTE (both roles had it before
-- the drop). `PUBLIC` is not granted: a new function gets a default PUBLIC
-- EXECUTE, and this revokes it before the two real grants.
REVOKE ALL ON FUNCTION public.search_map(
  text, text, text, uuid, uuid, uuid,
  numeric, numeric, numeric, numeric,
  integer, text, integer, text,
  numeric, numeric,
  numeric, numeric, numeric, numeric
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.search_map(
  text, text, text, uuid, uuid, uuid,
  numeric, numeric, numeric, numeric,
  integer, text, integer, text,
  numeric, numeric,
  numeric, numeric, numeric, numeric
) TO anon, authenticated;

COMMENT ON FUNCTION public.search_map(
  text, text, text, uuid, uuid, uuid,
  numeric, numeric, numeric, numeric,
  integer, text, integer, text,
  numeric, numeric,
  numeric, numeric, numeric, numeric
) IS
  'Map markers for the visible viewport, newest first, hard-capped at 500 rows '
  '(Plan A17). The bounding box is measured against the PUBLISHED marker '
  'coordinates, never the true ones — see 20260902120002_seal_map_jitter_oracle.';

NOTIFY pgrst, 'reload schema';
