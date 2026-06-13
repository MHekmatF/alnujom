-- Phase 030 (W1 — Video compression + poster thumbnails) — re-defines
-- public.list_video_reels() so the reels poster prefers the video's own
-- generated poster frame (listing_media.thumbnail_path, added in
-- 20260614120002) and only falls back to the listing's first image when the
-- video has no poster.
--
-- This is a VERBATIM copy of 20260613120005_create_list_video_reels_rpc.sql
-- with exactly two changes:
--   (a) the video LATERAL also selects lm.thumbnail_path, and
--   (b) the projected poster_image_path becomes
--       coalesce(vid.thumbnail_path, img.storage_path).
-- The signature, (published_at, id) keyset, ordering, limit clamp, and grants
-- (REVOKE PUBLIC/anon then GRANT anon, authenticated) are unchanged.

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
    l.id                                          AS listing_id,
    l.title                                       AS title,
    l.property_type                               AS property_type,
    l.purpose                                     AS purpose,
    g.display_name->>'ar'                         AS governorate_name_ar,
    g.display_name->>'en'                         AS governorate_name_en,
    c.display_name->>'ar'                         AS city_name_ar,
    c.display_name->>'en'                         AS city_name_en,
    p.amount                                      AS primary_amount,
    p.currency_code                               AS primary_currency,
    l.published_at                                AS published_at,
    vid.storage_path                              AS video_path,
    -- Phase 030 (W1) — prefer the video's own poster frame; fall back to the
    -- listing's first image when the video has no generated thumbnail.
    coalesce(vid.thumbnail_path, img.storage_path) AS poster_image_path
  FROM public.listings l
  JOIN LATERAL (
    -- Phase 030 (W1) — also surface the poster path for the chosen video.
    SELECT lm.storage_path, lm.thumbnail_path
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
  'p_before_published_at / p_before_id. Anon-readable browsing surface. '
  'Phase 030 (W1): poster prefers the video''s own thumbnail_path, falling back '
  'to the listing''s first image.';

REVOKE ALL ON FUNCTION public.list_video_reels(integer, timestamptz, uuid) FROM PUBLIC, anon;
-- Deliberate anon grant: anonymous browsing surface.
GRANT EXECUTE ON FUNCTION public.list_video_reels(integer, timestamptz, uuid) TO anon, authenticated;
