-- Phase 029 (W4 — Reels) — list_video_reels(): keyset-paginated feed of
-- approved, in-window, PUBLISHED listings that carry at least one video.
--
-- Powers the home "Reels" rail (first page) and the fullscreen vertical video
-- feed (subsequent pages via the (published_at, id) keyset). Every column it
-- projects is already anon-visible under the Phase-10/11 RLS policies
-- (listings.listings_select_public, listing_media.listing_media_anon_select_when_approved,
-- listing_prices.listing_prices_select_inherited, and the public governorates/
-- cities lookups), so the function is SECURITY DEFINER purely to keep the
-- LATERAL "first video / first image / primary price" sub-selects fast and out
-- of RLS re-evaluation per row.
--
-- SCHEMA NOTES (verified against the live migrations):
-- - listings: status / published_at / expires_at / governorate_id / city_id /
--   property_type / purpose (20260519120002_create_listings.sql).
-- - listing_media: kind ('video'|'image'|...), storage_path, ordering, is_main
--   (20260522120001_create_listing_media.sql). Videos live in the
--   `listing-videos` bucket, images in `listing-images` (resolved to public
--   URLs in the Dart data layer, not here).
-- - listing_prices: amount NUMERIC(14,2), currency_code, is_primary
--   (20260519120004_create_listing_prices.sql).
-- - governorates/cities: bilingual JSONB display_name {"ar":...,"en":...}
--   (mirrors v_listings_public projection in 20260525120002).

CREATE OR REPLACE FUNCTION public.list_video_reels(
  p_limit integer DEFAULT 10,
  p_before_published_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL
)
RETURNS TABLE(
  listing_id uuid,
  title text,
  property_type text,
  purpose text,
  governorate_name_ar text,
  governorate_name_en text,
  city_name_ar text,
  city_name_en text,
  primary_amount numeric,
  primary_currency text,
  published_at timestamptz,
  video_path text,
  poster_image_path text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    l.id                          AS listing_id,
    l.title                       AS title,
    l.property_type               AS property_type,
    l.purpose                     AS purpose,
    g.display_name->>'ar'         AS governorate_name_ar,
    g.display_name->>'en'         AS governorate_name_en,
    c.display_name->>'ar'         AS city_name_ar,
    c.display_name->>'en'         AS city_name_en,
    p.amount                      AS primary_amount,
    p.currency_code               AS primary_currency,
    l.published_at                AS published_at,
    vid.storage_path              AS video_path,
    img.storage_path              AS poster_image_path
  FROM public.listings l
  JOIN LATERAL (
    SELECT lm.storage_path
    FROM public.listing_media lm
    WHERE lm.listing_id = l.id
      AND lm.kind = 'video'
    ORDER BY lm.ordering ASC
    LIMIT 1
  ) vid ON true
  LEFT JOIN LATERAL (
    SELECT lm.storage_path
    FROM public.listing_media lm
    WHERE lm.listing_id = l.id
      AND lm.kind = 'image'
    ORDER BY lm.is_main DESC, lm.ordering ASC
    LIMIT 1
  ) img ON true
  LEFT JOIN public.governorates g ON g.id = l.governorate_id
  LEFT JOIN public.cities       c ON c.id = l.city_id
  LEFT JOIN LATERAL (
    SELECT lp.amount, lp.currency_code
    FROM public.listing_prices lp
    WHERE lp.listing_id = l.id
      AND lp.is_primary = true
    LIMIT 1
  ) p ON true
  WHERE l.status = 'approved'
    AND (l.expires_at IS NULL OR l.expires_at > now())
    AND l.published_at IS NOT NULL
    AND (
      p_before_published_at IS NULL
      OR (l.published_at, l.id) < (p_before_published_at, p_before_id)
    )
  ORDER BY l.published_at DESC, l.id DESC
  LIMIT least(coalesce(p_limit, 10), 30);
$$;

COMMENT ON FUNCTION public.list_video_reels(integer, timestamptz, uuid) IS
  'Phase 029 (Reels W4) — keyset-paginated feed of approved/in-window/published '
  'listings that have at least one video. (published_at, id) DESC keyset via '
  'p_before_published_at / p_before_id. Anon-readable browsing surface.';

REVOKE ALL ON FUNCTION public.list_video_reels(integer, timestamptz, uuid) FROM PUBLIC, anon;
-- Deliberate anon grant: anonymous browsing surface.
GRANT EXECUTE ON FUNCTION public.list_video_reels(integer, timestamptz, uuid) TO anon, authenticated;
