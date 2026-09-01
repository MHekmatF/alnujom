-- 20260901120002_revoke_authenticated_listing_coordinates
--
-- SEC-I1 residual (docs/qa/e2e-2026-07-16/SECURITY_AUDIT.md) — STEP 2 of 2.
--
-- ⚠ PREREQUISITES — apply IN THIS ORDER, and not before both are true:
--   1. `20260901120001_gate_listing_coordinates.sql` is applied.
--   2. An app build from that same commit is the one users are running.
--      Older builds still `select('*')` on public.listings from the listing edit
--      form, the admin revision diff and the admin listing preview; this
--      migration makes those three screens fail with
--      `permission denied for table listings` (PostgREST 42501).
-- Rollback is a single statement:
--   grant select (latitude, longitude) on public.listings to authenticated;
--
-- WHAT THIS CLOSES: `20260717120007` revoked latitude/longitude from `anon`, but
-- `authenticated` kept a TABLE-WIDE SELECT — so any signed-up user could
--     GET /rest/v1/listings?select=id,latitude,longitude&status=eq.approved
-- and lift the EXACT pin of every listing, defeating the `approximate`
-- location-visibility jitter that 100% of current listings rely on.
--
-- WHY REVOKE-THEN-RE-GRANT rather than a column-level REVOKE: a column-level
-- revoke does not restrict a role that holds the TABLE-level grant (Postgres
-- treats the table grant as covering every column, present and future). Same
-- shape as `20260717120007`'s anon fix — drop the table grant, then re-grant
-- every column EXCEPT the two coordinates.
--
-- The 29 columns below are public.listings' complete non-coordinate column set
-- (20260519120002 create + search_vector 20260525120001 + featured_until
-- 20260608120001 + deed_type/finish_level/verification_status/verified_at
-- 20260706171621) — identical to the list 20260717120007 granted to anon.
-- ⚠ MAINTENANCE: a future `ALTER TABLE public.listings ADD COLUMN` must also add
-- the column here (or in its own grant) or `authenticated` will not be able to
-- read it.
--
-- Owner/admin coordinate reads survive via public.get_listing_coordinates();
-- the public map survives via public.listing_marker_coordinates(); server-side
-- SECURITY DEFINER code (submit_listing, begin/apply_listing_revision, the map
-- jitter, search_listings/search_map, the Edge Functions' service_role client)
-- runs as owner/service_role and is unaffected.
revoke select on public.listings from authenticated;
grant select (
  id, publisher_user_id, agency_id, purpose, property_type, status, title,
  governorate_id, city_id, area_id, address_text, location_visibility, phone,
  whatsapp, contact_name_visibility, area_size, rooms, bathrooms, floor,
  created_at, updated_at, published_at, expires_at, search_vector, featured_until,
  deed_type, finish_level, verification_status, verified_at
) on public.listings to authenticated;

-- Re-assert the anon posture from 20260717120007 so the two roles cannot drift
-- (idempotent; a no-op when that migration is already in place).
revoke select on public.listings from anon;
grant select (
  id, publisher_user_id, agency_id, purpose, property_type, status, title,
  governorate_id, city_id, area_id, address_text, location_visibility, phone,
  whatsapp, contact_name_visibility, area_size, rooms, bathrooms, floor,
  created_at, updated_at, published_at, expires_at, search_vector, featured_until,
  deed_type, finish_level, verification_status, verified_at
) on public.listings to anon;

COMMENT ON COLUMN public.listings.latitude IS
  'SEC-I1: NOT readable by anon or authenticated. Public marker reads go through '
  'public.listing_marker_coordinates(); owner/admin reads through '
  'public.get_listing_coordinates(). Writes are unaffected (RLS-gated UPDATE).';
COMMENT ON COLUMN public.listings.longitude IS
  'SEC-I1: NOT readable by anon or authenticated. Public marker reads go through '
  'public.listing_marker_coordinates(); owner/admin reads through '
  'public.get_listing_coordinates(). Writes are unaffected (RLS-gated UPDATE).';
