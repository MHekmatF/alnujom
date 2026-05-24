# `public.map_jitter_coordinates` — Phase 15 map view jitter function

## Purpose

Server-side deterministic coordinate jitter for listings whose `location_visibility = 'approximate'`. The function is the privacy-critical core of Phase 15: a publisher's true `(latitude, longitude)` MUST NEVER leak to the public map; instead, the `v_listings_map_public` view projects a jittered position computed by this function.

## Signature

```sql
public.map_jitter_coordinates(
  p_listing_id   uuid,
  p_area_id      uuid,
  p_original_lat numeric,
  p_original_lng numeric
) RETURNS TABLE(jittered_lat numeric, jittered_lng numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
```

## Behavioral contract

1. **Determinism**: For a fixed salt (see "Salt storage" below), the function returns the same `(jittered_lat, jittered_lng)` pair for the same `p_listing_id` on every call. Reordering / concurrency / call frequency do NOT affect output.
2. **Salt dependency**: Reads the salt from Supabase Vault (secret `name = 'map_jitter_salt'`). If absent or empty, raises `EXCEPTION 'vault secret "map_jitter_salt" is not set; Phase 15 setup incomplete'`.
3. **Salt rotation**: Re-running `vault.update_secret(<secret_id>, '<new-hex>', ...)` causes every approximate listing's jitter output to change. Acceptable per FR-003 (the marker was always approximate; the user has no displacement guarantee across rotations).
4. **Area-centroid fallback**: When `p_original_lat` OR `p_original_lng` is `NULL`, the function anchors on `(public.areas.centroid_lat, .centroid_lng)` (Phase 10 R-12). If `p_area_id` resolves to no row OR the area has null centroids, raises `EXCEPTION 'area % missing centroid; cannot jitter', p_area_id`.
5. **Jitter radius**: Pre-clamp offset bounded by `±0.0045°` lat and `±0.0045°` lng (~500m at Syrian latitudes).
6. **Area-bounds clamp**: Post-jitter coordinates clamped to `±0.02°` around the area's centroid (~2.2km), so the marker stays within the publisher's declared area even when stored coords are far from the centroid.
7. **No PostGIS dependency**: Uses only plain `numeric` arithmetic, `extensions.digest()` from `pgcrypto` (already enabled), and standard PL/pgSQL constructs. PostGIS deferred per R-90.
8. **No side effects**: No INSERT/UPDATE/DELETE. No audit log writes. Pure read.

## Permissions

```sql
REVOKE ALL ON FUNCTION public.map_jitter_coordinates(uuid, uuid, numeric, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.map_jitter_coordinates(uuid, uuid, numeric, numeric) TO authenticated, anon;
```

The function is `SECURITY DEFINER` because non-superuser roles cannot read `vault.decrypted_secrets`. The function owner (postgres) reads the salt; callers see only the jittered output — never the salt itself.

## Salt storage — DEVIATION from research.md R-92

**Plan-time decision (R-92)**: Store salt in a Postgres GUC via `ALTER DATABASE postgres SET app.map_jitter_salt = '<hex>'`.

**Implementation deviation**: On Supabase, the `postgres` role available to the project owner cannot set parameters in the custom `app.*` GUC namespace (`permission denied to set parameter "app.map_jitter_salt"` — that namespace requires superuser, which is reserved to the Supabase platform). We use Supabase Vault instead, which:

- Aligns with project memory `project_secrets_storage.md` + ADR-0001 ("backend secrets and admin-only per-user PII go in Supabase Vault").
- Is callable from a `SECURITY DEFINER` function via `vault.decrypted_secrets`.
- Never exposes the secret value to anon / authenticated clients (the decrypted_secrets view is restricted to the secret owner).
- Survives database restarts and pooler reconnects (unlike session-scoped `SET`).

This deviation is captured in `specs/015-map-view/DEFERRED.md`.

## One-time setup procedure

```sql
-- Generate a 256-bit (64 hex chars) salt OUT OF BAND via:
--   PowerShell:
--     $bytes = New-Object byte[] 32
--     [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
--     ($bytes | ForEach-Object { '{0:x2}' -f $_ }) -join ''
--   OR Bash:
--     openssl rand -hex 32

-- Store in Vault:
SELECT vault.create_secret(
  '<256-bit-hex>',
  'map_jitter_salt',
  'Phase 15 jitter salt — rotation re-jitters every approximate marker per FR-003'
);

-- Verify (the function reads via vault.decrypted_secrets):
SELECT length(decrypted_secret) AS hex_length
FROM vault.decrypted_secrets
WHERE name = 'map_jitter_salt';
-- Expected: 64
```

The raw salt value MUST be saved to the project's password manager / secrets store. Losing it means every approximate listing's marker position will reset when a new salt is generated (acceptable but disruptive).

## Rotation procedure

```sql
-- Identify the secret id
SELECT id FROM vault.secrets WHERE name = 'map_jitter_salt';

-- Generate a new salt out of band (same procedure as setup).

-- Update:
SELECT vault.update_secret(
  '<secret-id-from-above>',
  '<new-256-bit-hex>',
  'map_jitter_salt',
  'Rotated YYYY-MM-DD — re-jitters every approximate marker'
);
```

After rotation, the next call to `v_listings_map_public` will return new jittered coordinates for every approximate listing. The marker dataset on running clients refreshes on `MapRefreshButton` tap (Phase 15 R-89).

## Smoke test queries

```sql
-- Determinism: same listing returns same coords across calls
SELECT * FROM public.map_jitter_coordinates(
  '00000000-0000-0000-0000-000000000001'::uuid,
  (SELECT id FROM public.areas ORDER BY id LIMIT 1),
  33.5138, 36.2765
);
SELECT * FROM public.map_jitter_coordinates(
  '00000000-0000-0000-0000-000000000001'::uuid,
  (SELECT id FROM public.areas ORDER BY id LIMIT 1),
  33.5138, 36.2765
);
-- Expected: identical (lat, lng) pairs

-- Different listing IDs anchored inside the area envelope produce different offsets
WITH a AS (SELECT id, centroid_lat, centroid_lng FROM public.areas ORDER BY id LIMIT 1)
SELECT 'listing1' AS label, j.jittered_lat, j.jittered_lng
FROM a, LATERAL public.map_jitter_coordinates(
  '00000000-0000-0000-0000-000000000001'::uuid, a.id, a.centroid_lat, a.centroid_lng
) j
UNION ALL
SELECT 'listing2', j.jittered_lat, j.jittered_lng
FROM a, LATERAL public.map_jitter_coordinates(
  '00000000-0000-0000-0000-000000000002'::uuid, a.id, a.centroid_lat, a.centroid_lng
) j;
-- Expected: different (lat, lng) pairs

-- Null lat/lng triggers area-centroid fallback
SELECT a.centroid_lat, a.centroid_lng, j.jittered_lat, j.jittered_lng
FROM public.areas a
CROSS JOIN LATERAL public.map_jitter_coordinates(
  '00000000-0000-0000-0000-000000000003'::uuid, a.id, NULL, NULL
) j
WHERE a.id = (SELECT id FROM public.areas ORDER BY id LIMIT 1);
-- Expected: jittered coords within ±0.02° of the area centroid

-- Clamp invariant
SELECT count(*) AS clamp_violations
FROM public.v_listings_map_public v
JOIN public.listings l ON l.id = v.id
JOIN public.areas a ON a.id = l.area_id
WHERE v.is_approximate = true
  AND (v.marker_lat < a.centroid_lat - 0.02 OR v.marker_lat > a.centroid_lat + 0.02
       OR v.marker_lng < a.centroid_lng - 0.02 OR v.marker_lng > a.centroid_lng + 0.02);
-- Expected: 0

-- Missing salt raises (test in a disposable branch only — DO NOT delete the live secret)
-- DELETE FROM vault.secrets WHERE name = 'map_jitter_salt';
-- SELECT * FROM public.map_jitter_coordinates(...);
-- Expected: ERROR 'vault secret "map_jitter_salt" is not set; Phase 15 setup incomplete'
```
