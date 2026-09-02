-- 20260902120002_seal_map_jitter_oracle
--
-- SECURITY FIX — the `approximate` location-visibility jitter could be undone
-- by anyone holding the public anon key. Two RPC calls recovered a listing's
-- EXACT latitude/longitude to the last decimal place.
--
-- HOW THE LEAK WORKED
--   `map_jitter_coordinates(p_listing_id, p_area_id, p_original_lat, p_original_lng)`
--   took the true coordinates as CALLER-SUPPLIED ARGUMENTS and added a secret
--   offset derived from `sha256(listing_id || vault salt)`. The offset is
--   deterministic per listing — that is the point, the pin must not wander
--   between page loads — but it made the function a decryption oracle:
--
--     1. read the public marker            m   = true + offset
--        (`v_listings_map_public`, or `listing_marker_coordinates`; both public)
--     2. call this function with m as the anchor
--                                          m'  = m + offset
--     3. offset = m' - m,  and therefore   true = m - offset
--
--   Verified against the live database on 2026-09-02 with nothing but
--   SUPABASE_ANON_KEY: recovered 33.511000 / 36.306000 for a listing whose
--   stored coordinates are 33.511000 / 36.306000. Error 0.000000 on both axes.
--
--   Step 2 is the whole vulnerability. The ±0.02° clamp around the area
--   centroid happens to defeat it for listings that sit far from their centroid
--   (both readings clamp to the same bound), but that is luck, not a control —
--   a listing near its area centroid, which is the normal case, gives the exact
--   pin every time.
--
-- THE FIX (two layers; either alone would close it, both are cheap)
--   (a) The function no longer trusts the caller for the thing it is protecting.
--       It reads `public.listings.latitude/longitude` for `p_listing_id` itself.
--       `p_original_lat` / `p_original_lng` are now IGNORED — kept only so the
--       signature is unchanged and `listing_marker_coordinates` keeps compiling.
--       That single change makes the oracle useless for every role, now and
--       after any future re-GRANT.
--   (b) EXECUTE is revoked from `anon` and `authenticated`. This function has no
--       external caller left — see below — so nobody outside the database needs
--       to call it at all.
--
-- WHY THE REVOKE IS SAFE NOW, THOUGH IT WAS NOT IN JULY
--   `20260717120010` deliberately left the anon grant in place, with the note
--   "called by the security_invoker view v_listings_map_public, so anon needs
--   EXECUTE for the public map to work". That was true then and became stale
--   YESTERDAY: `20260901120001` rebuilt the view on top of
--   `listing_marker_coordinates(...)`, which is SECURITY DEFINER. Inside a
--   SECURITY DEFINER function PostgreSQL checks EXECUTE against the function
--   OWNER, not the session role, so the inner jitter call no longer needs
--   anything from the caller. Confirmed live: no view, no RLS policy and no
--   client-side call site references `map_jitter_coordinates` any more; the only
--   remaining caller in the whole database is `listing_marker_coordinates`.
--
-- NO MARKER MOVES. `listing_marker_coordinates` already passed
-- `listings.latitude/longitude` for the same `p_listing_id` — precisely what the
-- lookup now fetches — so every published pin keeps its current position. The
-- salt, the hash, the ±0.0045° radius and the ±0.02° clamp are untouched.
--
-- Idempotent: CREATE OR REPLACE + REVOKE are both safe to re-run.

create or replace function public.map_jitter_coordinates(
  p_listing_id     uuid,
  p_area_id        uuid,
  p_original_lat   numeric,
  p_original_lng   numeric
)
returns table(jittered_lat numeric, jittered_lng numeric)
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  v_salt           text;
  v_hash           bytea;
  v_byte_lat       bigint;
  v_byte_lng       bigint;
  v_offset_lat     numeric;
  v_offset_lng     numeric;
  v_anchor_lat     numeric;
  v_anchor_lng     numeric;
  v_true_lat       numeric;
  v_true_lng       numeric;
  v_centroid_lat   numeric;
  v_centroid_lng   numeric;
  v_jitter_radius  CONSTANT numeric := 0.0045;
  v_clamp_radius   CONSTANT numeric := 0.02;
BEGIN
  SELECT decrypted_secret
    INTO v_salt
  FROM vault.decrypted_secrets
  WHERE name = 'map_jitter_salt'
  LIMIT 1;
  IF v_salt IS NULL OR v_salt = '' THEN
    RAISE EXCEPTION 'vault secret "map_jitter_salt" is not set; Phase 15 setup incomplete';
  END IF;

  SELECT centroid_lat, centroid_lng
    INTO v_centroid_lat, v_centroid_lng
  FROM public.areas
  WHERE id = p_area_id;
  IF v_centroid_lat IS NULL OR v_centroid_lng IS NULL THEN
    RAISE EXCEPTION 'area % missing centroid; cannot jitter', p_area_id;
  END IF;

  -- The anchor comes from the LISTING, never from the caller. Accepting it as an
  -- argument is what turned this function into an offset oracle: feed it the
  -- published marker and subtract, and the secret offset falls out. See header.
  SELECT l.latitude, l.longitude
    INTO v_true_lat, v_true_lng
  FROM public.listings AS l
  WHERE l.id = p_listing_id;

  v_anchor_lat := COALESCE(v_true_lat, v_centroid_lat);
  v_anchor_lng := COALESCE(v_true_lng, v_centroid_lng);

  v_hash := extensions.digest(p_listing_id::text || v_salt, 'sha256');
  v_byte_lat := (get_byte(v_hash, 0)::bigint << 24)
              | (get_byte(v_hash, 1)::bigint << 16)
              | (get_byte(v_hash, 2)::bigint <<  8)
              |  get_byte(v_hash, 3)::bigint;
  v_byte_lng := (get_byte(v_hash, 4)::bigint << 24)
              | (get_byte(v_hash, 5)::bigint << 16)
              | (get_byte(v_hash, 6)::bigint <<  8)
              |  get_byte(v_hash, 7)::bigint;

  v_offset_lat := ((v_byte_lat::numeric / 2147483647.5) - 1.0) * v_jitter_radius;
  v_offset_lng := ((v_byte_lng::numeric / 2147483647.5) - 1.0) * v_jitter_radius;

  jittered_lat := v_anchor_lat + v_offset_lat;
  jittered_lng := v_anchor_lng + v_offset_lng;

  jittered_lat := GREATEST(v_centroid_lat - v_clamp_radius,
                  LEAST(v_centroid_lat + v_clamp_radius, jittered_lat));
  jittered_lng := GREATEST(v_centroid_lng - v_clamp_radius,
                  LEAST(v_centroid_lng + v_clamp_radius, jittered_lng));

  RETURN NEXT;
END;
$function$;

comment on function public.map_jitter_coordinates(uuid, uuid, numeric, numeric) is
  'Phase 15 map jitter. INTERNAL — call listing_marker_coordinates(uuid) instead; '
  'EXECUTE is revoked from anon and authenticated on purpose. Returns a stable '
  'per-listing offset applied to the listing''s OWN stored coordinates, clamped to '
  'the area centroid +/- 0.02deg. p_original_lat / p_original_lng are DEPRECATED and '
  'ignored: taking the true position from the caller let anyone recover the secret '
  'offset by re-feeding the published marker (see 20260902120002).';

-- No external caller remains. listing_marker_coordinates is SECURITY DEFINER, so
-- its inner call is authorised as the function owner, not as the session role.
revoke execute on function public.map_jitter_coordinates(uuid, uuid, numeric, numeric)
  from anon, authenticated, public;
