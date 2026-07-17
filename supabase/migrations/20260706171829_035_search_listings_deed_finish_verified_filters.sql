-- 20260706171829_035_search_listings_deed_finish_verified_filters
--
-- RECONSTRUCTED 2026-07-17 from the live database (commit-only — already applied
-- via Supabase MCP on 2026-07-06 as tracker version 20260706171829). DO NOT
-- re-apply through MCP (DB-1 fix). Body below is the current live
-- `pg_get_functiondef` output AS APPLIED ON 2026-07-06 — it still carries the
-- single-bound price bug (FUNC-H1 / DB-2). The bug is fixed by the later migration
-- 20260717120002_fix_search_listings_price_bounds.sql; this file is the faithful
-- pre-fix snapshot so the history reads correctly (035 shipped it, 07-17 fixed it).
--
-- Phase 035 Stage 3 — adds the Syria-native deed/finish + verified-only filters to
-- the search RPC (p_deed_type / p_finish_level / p_verified_only).
create or replace function public.search_listings(
  p_query text default null::text,
  p_purpose text default null::text,
  p_property_type text default null::text,
  p_governorate_id uuid default null::uuid,
  p_city_id uuid default null::uuid,
  p_area_id uuid default null::uuid,
  p_price_min_usd numeric default null::numeric,
  p_price_max_usd numeric default null::numeric,
  p_price_min_syp numeric default null::numeric,
  p_price_max_syp numeric default null::numeric,
  p_rooms integer default null::integer,
  p_rooms_mode text default 'exactly'::text,
  p_bathrooms integer default null::integer,
  p_bathrooms_mode text default 'exactly'::text,
  p_area_size_min numeric default null::numeric,
  p_area_size_max numeric default null::numeric,
  p_sort text default 'newest'::text,
  p_cursor_published_at timestamp with time zone default null::timestamp with time zone,
  p_cursor_id_newest uuid default null::uuid,
  p_cursor_price_amount numeric default null::numeric,
  p_cursor_id_price uuid default null::uuid,
  p_limit integer default 20,
  p_is_agency boolean default null::boolean,
  p_furnished boolean default null::boolean,
  p_parking boolean default null::boolean,
  p_amenities jsonb default null::jsonb,
  p_deed_type text default null::text,
  p_finish_level text default null::text,
  p_verified_only boolean default null::boolean
)
 returns setof search_result_row
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
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
    AND (p_furnished IS NULL OR ld.furnished = p_furnished)
    AND (p_parking   IS NULL OR ld.parking   = p_parking)
    AND (p_amenities IS NULL OR ld.amenities @> p_amenities)
    -- Phase 035 Stage 3 — Syria-native + verification filters.
    AND (p_deed_type    IS NULL OR v.deed_type    = p_deed_type)
    AND (p_finish_level IS NULL OR v.finish_level = p_finish_level)
    AND (p_verified_only IS NOT TRUE OR v.verification_status = 'verified')
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
$function$;
