-- 20260717120007_revoke_anon_listing_coordinates
--
-- QA E2E fix — SEC-I1 (privacy): anon could read exact latitude/longitude straight
-- off public.listings for every approved listing (all currently 'approximate'
-- visibility), bypassing the jitter — a bulk-scrape of exact home locations with no
-- login. anon had TABLE-WIDE select, so a column-level revoke alone wouldn't restrict
-- it; revoke the table grant and re-grant every column EXCEPT the coordinates. anon
-- still reads the base table for the listing-detail page; exact coordinates now flow
-- to clients only through the visibility-gated v_listings_map_public (definer) view
-- (the detail datasource was switched to that view — SEC-I1 client half).
--
-- Verified live 2026-07-17: has_column_privilege('anon', …, 'latitude'/'longitude',
-- 'select') = false; other columns + authenticated access unchanged.
--
-- Residual (tracked follow-up): `authenticated` still has table-wide SELECT, so a
-- signed-up user can read others' exact coords via the base table. Fully closing that
-- needs an owner/admin-only coordinate RPC + reworking the edit-form + revision
-- datasources (which currently `.select()` all columns) — deferred so the location
-- edit flow can be tested. The anon (no-login) bulk vector — by far the most severe —
-- is closed here.
revoke select on public.listings from anon;
grant select (
  id, publisher_user_id, agency_id, purpose, property_type, status, title,
  governorate_id, city_id, area_id, address_text, location_visibility, phone,
  whatsapp, contact_name_visibility, area_size, rooms, bathrooms, floor,
  created_at, updated_at, published_at, expires_at, search_vector, featured_until,
  deed_type, finish_level, verification_status, verified_at
) on public.listings to anon;
