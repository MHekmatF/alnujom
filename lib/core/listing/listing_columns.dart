// lib/core/listing/listing_columns.dart
//
// SEC-I1 (docs/qa/e2e-2026-07-16/SECURITY_AUDIT.md) — the PostgREST projection
// for `public.listings`.
//
// Migration `20260901120002_revoke_authenticated_listing_coordinates.sql`
// removes `latitude` / `longitude` from the `anon` + `authenticated` SELECT
// grant, so `select('*')` (and a bare `.select()`, and the implicit
// `RETURNING *` behind `.insert(…).select()`) now fails the whole request with
// `permission denied for table listings`. Every owner/admin read of the table
// must therefore name its columns.
//
// Exact coordinates are fetched separately, and only for a caller who owns or
// can moderate the listing, via the `get_listing_coordinates` RPC
// (`SupabaseCoordinatesReader`). The public map reads its already-gated marker
// from `v_listings_map_public`.
//
// ⚠ KEEP IN SYNC: this list must equal the column set granted in
// `20260901120002…` (which in turn equals `20260717120007`'s anon grant). A new
// `ALTER TABLE public.listings ADD COLUMN` needs the column added in BOTH
// places, or it will be silently missing from every read here.
//
// Plain Dart — no SDK import, so this is safe to sit in `lib/core/`
// (Constitution IX).

/// All 29 non-coordinate columns of `public.listings`, as a PostgREST
/// `select=` projection. Use instead of `*` wherever the caller is an owner or
/// an admin reading the base table.
const String listingColumnsWithoutCoordinates =
    'id, publisher_user_id, agency_id, purpose, property_type, status, title, '
    'governorate_id, city_id, area_id, address_text, location_visibility, '
    'phone, whatsapp, contact_name_visibility, area_size, rooms, bathrooms, '
    'floor, created_at, updated_at, published_at, expires_at, search_vector, '
    'featured_until, deed_type, finish_level, verification_status, verified_at';
