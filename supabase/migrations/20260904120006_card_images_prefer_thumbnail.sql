-- Serve a thumbnail to every card that only ever needed a thumbnail.
--
-- Uploads are resized to a 1920-px long edge and stored at ~156 KB average.
-- Every card in the app then downloads that full file: the home feed alone is
-- twenty of them, about **3 MB per open**. `AppNetworkImage.memCacheWidth` caps
-- the *decode*, and Data-saver caps the *disk cache*, but neither caps the
-- transfer — the bytes come down the wire regardless. On Syrian mobile data
-- that is the single most expensive thing the app does (review 2026-09-04, P1).
--
-- Supabase image transforms are a Pro-plan feature, so the thumbnail is made on
-- the device at upload time (see tool/backfill_listing_thumbnails.py for the
-- existing rows) and stored in `listing_media.thumbnail_path` — the column
-- already exists; video posters have used it since Phase 029.
--
-- These four views are every place a *card* image is chosen. Each one's LATERAL
-- now prefers the thumbnail and falls back to the full file, so a row without a
-- thumbnail keeps working exactly as before and the backfill can run at its own
-- pace. The listing DETAIL gallery does not come through here — it reads
-- `listing_media` directly and keeps the full-resolution file, which is the
-- point of having both.
--
-- Only the LATERAL sub-select changed in each view; every column name, type and
-- order is identical, and the `security_invoker` reloption is re-stated because
-- CREATE OR REPLACE VIEW does not carry it over on its own.

-- ---------------------------------------------------------------------------
-- Search results
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_listings_public AS
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
    lm.card_path AS main_image_path,
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
     LEFT JOIN LATERAL ( SELECT COALESCE(listing_media.thumbnail_path, listing_media.storage_path) AS card_path
           FROM listing_media
          WHERE listing_media.listing_id = l.id AND listing_media.kind = 'image'::text
          ORDER BY listing_media.ordering
         LIMIT 1) lm ON true
     LEFT JOIN governorates g ON g.id = l.governorate_id
     LEFT JOIN cities c ON c.id = l.city_id
     LEFT JOIN agencies ag ON ag.id = l.agency_id AND ag.status = 'approved'::agency_status
  WHERE l.status = 'approved'::text AND (l.expires_at IS NULL OR l.expires_at > now());

-- ---------------------------------------------------------------------------
-- Map markers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_listings_map_public
WITH (security_invoker = true) AS
 SELECT l.id,
    l.title,
    marker.marker_lat,
    marker.marker_lng,
    l.location_visibility = 'approximate'::text AS is_approximate,
    l.location_visibility,
    lp.amount AS primary_amount,
    lp.currency_code AS primary_currency,
    lm.card_path AS main_image_path,
    l.property_type,
    l.purpose,
    g.display_name ->> 'ar'::text AS governorate_name_ar,
    g.display_name ->> 'en'::text AS governorate_name_en
   FROM listings l
     LEFT JOIN LATERAL listing_marker_coordinates(l.id) marker(marker_lat, marker_lng) ON true
     LEFT JOIN LATERAL ( SELECT listing_prices.amount,
            listing_prices.currency_code
           FROM listing_prices
          WHERE listing_prices.listing_id = l.id AND listing_prices.is_primary = true
         LIMIT 1) lp ON true
     LEFT JOIN LATERAL ( SELECT COALESCE(listing_media.thumbnail_path, listing_media.storage_path) AS card_path
           FROM listing_media
          WHERE listing_media.listing_id = l.id AND listing_media.kind = 'image'::text
          ORDER BY listing_media.ordering
         LIMIT 1) lm ON true
     LEFT JOIN governorates g ON g.id = l.governorate_id
  WHERE l.status = 'approved'::text
    AND (l.location_visibility = ANY (ARRAY['exact'::text, 'approximate'::text]))
    AND (l.published_at IS NULL OR l.published_at <= now())
    AND (l.expires_at IS NULL OR l.expires_at > now())
    AND marker.marker_lat IS NOT NULL AND marker.marker_lng IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Favourites
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_favorites
WITH (security_invoker = true) AS
 SELECT f.listing_id AS id,
    f.created_at AS favorited_at,
    l.title,
    l.property_type,
    l.purpose,
    lp.amount AS primary_amount,
    lp.currency_code AS primary_currency,
    lm.card_path AS main_image_path,
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
     LEFT JOIN LATERAL ( SELECT COALESCE(listing_media.thumbnail_path, listing_media.storage_path) AS card_path
           FROM listing_media
          WHERE listing_media.listing_id = l.id AND listing_media.kind = 'image'::text
          ORDER BY listing_media.ordering
         LIMIT 1) lm ON true
     LEFT JOIN governorates g ON g.id = l.governorate_id
     LEFT JOIN cities c ON c.id = l.city_id;

-- ---------------------------------------------------------------------------
-- Reports queue (mine + the moderator's)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_reports AS
 SELECT r.id,
    r.listing_id,
    r.reporter_user_id,
    r.reason,
    r.note,
    r.status,
    r.reviewing_by,
    r.resolved_by,
    r.resolution,
    r.created_at,
    r.resolved_at,
    l.title AS listing_title,
    l.status AS listing_status,
    lm.card_path AS main_image_path,
    g.display_name ->> 'ar'::text AS governorate_name_ar,
    g.display_name ->> 'en'::text AS governorate_name_en,
    c.display_name ->> 'ar'::text AS city_name_ar,
    c.display_name ->> 'en'::text AS city_name_en
   FROM reports r
     JOIN listings l ON l.id = r.listing_id
     LEFT JOIN governorates g ON g.id = l.governorate_id
     LEFT JOIN cities c ON c.id = l.city_id
     LEFT JOIN LATERAL ( SELECT COALESCE(m.thumbnail_path, m.storage_path) AS card_path
           FROM listing_media m
          WHERE m.listing_id = l.id AND m.is_main = true
          ORDER BY m.ordering
         LIMIT 1) lm ON true
  WHERE r.reporter_user_id = auth.uid() OR current_user_has_permission('reports.manage'::text);
