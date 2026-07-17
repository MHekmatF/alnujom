-- 20260706171704_035_expose_deed_finish_verification_in_public_view
--
-- RECONSTRUCTED 2026-07-17 from the live database (commit-only — already applied
-- via Supabase MCP on 2026-07-06 as tracker version 20260706171704). DO NOT
-- re-apply through MCP. Body below is the current live `pg_get_viewdef` output;
-- committed so the repo captures the live view (DB-1 fix). Column order matches
-- the earlier create so a from-scratch CREATE OR REPLACE replay stays valid.
--
-- Phase 035 Stage 3 — expose deed_type / finish_level / verification_status /
-- verified_at on the public listing projection so search + detail can surface the
-- Syria-native attributes and the field-verified badge.
create or replace view public.v_listings_public as
 SELECT l.id,
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
    lp.amount AS primary_amount,
    lp.currency_code AS primary_currency,
    lm.storage_path AS main_image_path,
    g.display_name ->> 'ar'::text AS governorate_name_ar,
    g.display_name ->> 'en'::text AS governorate_name_en,
    c.display_name ->> 'ar'::text AS city_name_ar,
    c.display_name ->> 'en'::text AS city_name_en,
    ag.id AS agency_id,
    ag.name AS agency_name,
    ag.logo_path AS agency_logo_path,
    l.deed_type,
    l.finish_level,
    l.verification_status,
    l.verified_at
   FROM listings l
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
     LEFT JOIN cities c ON c.id = l.city_id
     LEFT JOIN agencies ag ON ag.id = l.agency_id AND ag.status = 'approved'::agency_status
  WHERE l.status = 'approved'::text AND (l.expires_at IS NULL OR l.expires_at > now());
