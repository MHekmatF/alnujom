-- Phase 17 — Migration 3/5 — FavoritesPage projection (R-113).
-- SECURITY INVOKER so the base-table self-only RLS on public.favorites
-- applies to view reads (Phase 16 20260527120013 precedent). Projects only
-- public-safe listing columns — never a publisher private field.
-- Does NOT filter on l.status: unavailable favorites MUST still appear with
-- an is_available=false flag (Q4=A + FR-025).

CREATE OR REPLACE VIEW public.v_favorites
WITH (security_invoker = true) AS
SELECT
  f.listing_id                              AS id,
  f.created_at                              AS favorited_at,
  l.title,
  l.property_type,
  l.purpose,
  lp.amount                                 AS primary_amount,
  lp.currency_code                          AS primary_currency,
  lm.storage_path                           AS main_image_path,
  g.display_name->>'ar'                     AS governorate_name_ar,
  g.display_name->>'en'                     AS governorate_name_en,
  c.display_name->>'ar'                     AS city_name_ar,
  c.display_name->>'en'                     AS city_name_en,
  (l.status = 'approved'
    AND (l.expires_at IS NULL OR l.expires_at > now())) AS is_available
FROM public.favorites f
JOIN public.listings l ON l.id = f.listing_id
LEFT JOIN LATERAL (
  SELECT amount, currency_code
  FROM public.listing_prices
  WHERE listing_id = l.id AND is_primary = true
  LIMIT 1
) lp ON true
LEFT JOIN LATERAL (
  SELECT storage_path
  FROM public.listing_media
  WHERE listing_id = l.id AND kind = 'image'
  ORDER BY ordering ASC
  LIMIT 1
) lm ON true
LEFT JOIN public.governorates g ON g.id = l.governorate_id
LEFT JOIN public.cities       c ON c.id = l.city_id;

GRANT SELECT ON public.v_favorites TO authenticated;
-- NOT granted to anon.
