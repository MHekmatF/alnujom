-- Phase 25 uplift v2 — surface beds/baths/area/floor on favourite cards.
-- CREATE OR REPLACE preserves existing column order (appends new cols at end)
-- and the security_invoker=true setting (RLS evaluated as the caller).
create or replace view public.v_favorites
with (security_invoker = true) as
 SELECT f.listing_id AS id,
    f.created_at AS favorited_at,
    l.title,
    l.property_type,
    l.purpose,
    lp.amount AS primary_amount,
    lp.currency_code AS primary_currency,
    lm.storage_path AS main_image_path,
    g.display_name ->> 'ar'::text AS governorate_name_ar,
    g.display_name ->> 'en'::text AS governorate_name_en,
    c.display_name ->> 'ar'::text AS city_name_ar,
    c.display_name ->> 'en'::text AS city_name_en,
    COALESCE(l.status = 'approved'::text AND (l.expires_at IS NULL OR l.expires_at > now()), false) AS is_available,
    l.rooms,
    l.bathrooms,
    l.area_size,
    l.floor
   FROM favorites f
     LEFT JOIN listings l ON l.id = f.listing_id
     LEFT JOIN LATERAL ( SELECT listing_prices.amount,
            listing_prices.currency_code
           FROM listing_prices
          WHERE listing_prices.listing_id = l.id AND listing_prices.is_primary = true
         LIMIT 1) lp ON true
     LEFT JOIN LATERAL ( SELECT listing_media.storage_path
           FROM listing_media
          WHERE listing_media.listing_id = l.id AND listing_media.kind = 'image'::text
          ORDER BY listing_media.ordering
         LIMIT 1) lm ON true
     LEFT JOIN governorates g ON g.id = l.governorate_id
     LEFT JOIN cities c ON c.id = l.city_id;
