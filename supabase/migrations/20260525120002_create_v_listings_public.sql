-- Phase 14: Public listing projection view — approved, in-window listings only.
-- Read by search_listings RPC. Enforces status + publish-window at view level (R-81).
--
-- SCHEMA NOTE: data-model.md §1.2 references g.name_ar / g.name_en / c.name_ar /
-- c.name_en and lm.position. The live schema (per migrations 20260517120001 and
-- 20260522120001) stores bilingual names in display_name JSONB ({"ar":...,"en":...})
-- and uses ordering (not position) on listing_media. We preserve the spec's
-- OUTPUT column names (governorate_name_ar / governorate_name_en / city_name_ar /
-- city_name_en / main_image_path) by projecting display_name->>'ar' / 'en' and
-- ordering by lm.ordering ASC. Downstream Dart DTOs depend on the OUTPUT names,
-- not the underlying column names.

CREATE OR REPLACE VIEW public.v_listings_public AS
SELECT
  l.id,
  l.title,
  l.address_text,
  l.property_type,
  l.purpose,
  l.governorate_id,
  l.city_id,
  l.area_id,
  l.rooms,
  l.bathrooms,
  l.area_size,
  l.published_at,
  l.expires_at,
  l.search_vector,
  -- Primary price (is_primary = true row)
  lp.amount        AS primary_amount,
  lp.currency_code AS primary_currency,
  -- Main image (lowest ordering value among image-kind rows)
  lm.storage_path  AS main_image_path,
  -- Bilingual location names (JSONB display_name -> separate columns)
  g.display_name->>'ar' AS governorate_name_ar,
  g.display_name->>'en' AS governorate_name_en,
  c.display_name->>'ar' AS city_name_ar,
  c.display_name->>'en' AS city_name_en
FROM public.listings l
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
LEFT JOIN public.cities       c ON c.id = l.city_id
WHERE l.status = 'approved'
  AND (l.expires_at IS NULL OR l.expires_at > now());
