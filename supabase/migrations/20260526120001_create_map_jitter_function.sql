-- Phase 15 R-87: Deterministic per-listing coordinate jitter for
-- listings whose location_visibility = 'approximate'.
--
-- Strategy:
--   1. Hash listing_id concatenated with a Vault-stored salt via SHA-256.
--   2. Extract two 4-byte windows from the hash -> two unsigned 32-bit ints.
--   3. Normalize each to [-1, +1] then scale by 0.0045 deg (~500m at Syrian
--      latitudes) to produce a deterministic (lat_offset, lng_offset) pair.
--   4. Add the offset to the listing's stored (lat, lng); if those are null,
--      fall back to the listing's area's centroid (Phase 10 R-12).
--   5. Clamp the result to a +-0.02 deg rectangle around the area's centroid
--      so the marker stays within the publisher's declared area.
--
-- SECRET STORAGE — DEVIATION FROM R-92:
--   The plan originally proposed storing the salt in a Postgres GUC via
--   `ALTER DATABASE postgres SET app.map_jitter_salt = ...`. On Supabase the
--   `postgres` role available to the project owner cannot set custom GUC
--   namespaces (permission denied — `app.*` requires superuser, reserved for
--   the Supabase platform). We use Supabase Vault instead, which:
--     - aligns with project memory `project_secrets_storage.md` + ADR-0001
--       ("backend secrets and admin-only per-user PII go in Supabase Vault");
--     - is callable from a SECURITY DEFINER function;
--     - is never exposed to anon / authenticated clients (decrypted_secrets
--       view is restricted to the function owner).
--
-- The salt is created ONCE out-of-band by the platform admin via:
--   SELECT vault.create_secret('<256-bit-hex>', 'map_jitter_salt',
--                              'Phase 15 jitter salt — rotation re-jitters every approximate marker');
-- See supabase/docs/map_jitter_coordinates.md for setup + rotation procedure.
--
-- pgcrypto's digest() is already enabled (Phase 4). Vault is also enabled
-- (verified via pg_extension). No new extensions added here.

CREATE OR REPLACE FUNCTION public.map_jitter_coordinates(
  p_listing_id   uuid,
  p_area_id      uuid,
  p_original_lat numeric,
  p_original_lng numeric
)
RETURNS TABLE(jittered_lat numeric, jittered_lng numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_salt           text;
  v_hash           bytea;
  v_byte_lat       bigint;
  v_byte_lng       bigint;
  v_offset_lat     numeric;
  v_offset_lng     numeric;
  v_anchor_lat     numeric;
  v_anchor_lng     numeric;
  v_centroid_lat   numeric;
  v_centroid_lng   numeric;
  v_jitter_radius  CONSTANT numeric := 0.0045;  -- ~500m at Syrian latitudes
  v_clamp_radius   CONSTANT numeric := 0.02;    -- ~2.2km area-bounds clamp
BEGIN
  -- Read the salt from Vault. The decrypted_secrets view is restricted to the
  -- function owner (postgres) — anon/authenticated callers never see the salt
  -- value, only the function's jittered output. If no row exists, raise
  -- (deployment misconfiguration — must run vault.create_secret first).
  SELECT decrypted_secret
    INTO v_salt
  FROM vault.decrypted_secrets
  WHERE name = 'map_jitter_salt'
  LIMIT 1;
  IF v_salt IS NULL OR v_salt = '' THEN
    RAISE EXCEPTION 'vault secret "map_jitter_salt" is not set; Phase 15 setup incomplete';
  END IF;

  -- Look up the area centroid (Phase 10 R-12 — guaranteed non-null + bounds-checked
  -- by Syria-bounds CHECK constraint on public.areas).
  SELECT centroid_lat, centroid_lng
    INTO v_centroid_lat, v_centroid_lng
  FROM public.areas
  WHERE id = p_area_id;
  IF v_centroid_lat IS NULL OR v_centroid_lng IS NULL THEN
    RAISE EXCEPTION 'area % missing centroid; cannot jitter', p_area_id;
  END IF;

  -- Anchor: use the listing's stored coords if non-null, else the area centroid.
  v_anchor_lat := COALESCE(p_original_lat, v_centroid_lat);
  v_anchor_lng := COALESCE(p_original_lng, v_centroid_lng);

  -- Deterministic offset derivation via SHA-256(listing_id || salt).
  -- digest() lives in the `extensions` schema per Supabase convention;
  -- we qualify to keep search_path narrow (Constitution III defense in depth).
  v_hash := extensions.digest(p_listing_id::text || v_salt, 'sha256');
  -- Bytes 0..3 -> lat offset; bytes 4..7 -> lng offset.
  -- Compose unsigned 32-bit ints (big-endian byte order) using bigint to avoid overflow.
  v_byte_lat := (get_byte(v_hash, 0)::bigint << 24)
              | (get_byte(v_hash, 1)::bigint << 16)
              | (get_byte(v_hash, 2)::bigint <<  8)
              |  get_byte(v_hash, 3)::bigint;
  v_byte_lng := (get_byte(v_hash, 4)::bigint << 24)
              | (get_byte(v_hash, 5)::bigint << 16)
              | (get_byte(v_hash, 6)::bigint <<  8)
              |  get_byte(v_hash, 7)::bigint;

  -- Normalize [0, 2^32-1] -> [-1, +1] then scale to jitter radius.
  v_offset_lat := ((v_byte_lat::numeric / 2147483647.5) - 1.0) * v_jitter_radius;
  v_offset_lng := ((v_byte_lng::numeric / 2147483647.5) - 1.0) * v_jitter_radius;

  jittered_lat := v_anchor_lat + v_offset_lat;
  jittered_lng := v_anchor_lng + v_offset_lng;

  -- Clamp to +-v_clamp_radius around the area centroid.
  jittered_lat := GREATEST(v_centroid_lat - v_clamp_radius,
                  LEAST(v_centroid_lat + v_clamp_radius, jittered_lat));
  jittered_lng := GREATEST(v_centroid_lng - v_clamp_radius,
                  LEAST(v_centroid_lng + v_clamp_radius, jittered_lng));

  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.map_jitter_coordinates(uuid, uuid, numeric, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.map_jitter_coordinates(uuid, uuid, numeric, numeric) TO authenticated, anon;

COMMENT ON FUNCTION public.map_jitter_coordinates(uuid, uuid, numeric, numeric) IS
  'Phase 15 R-87: deterministic per-listing coordinate jitter for approximate listings. '
  'Reads salt from Supabase Vault (secret name: map_jitter_salt). Anchored on listing coords '
  'with area-centroid fallback. Clamped to +-0.02 deg around area centroid. '
  'Result is stable across fetches for a given (listing_id, salt) pair.';
