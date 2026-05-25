# Contract: `public.map_jitter_coordinates` SQL function

**Phase**: 15 — Map View
**Owner**: Sub-Phase C (backend)
**Migration**: `supabase/migrations/20260526120001_create_map_jitter_function.sql`
**Spec refs**: FR-003, FR-005, SC-003
**Research refs**: R-87 (algorithm), R-92 (salt storage)

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

1. **Determinism**: For a fixed `app.map_jitter_salt` value, the function MUST return the same `(jittered_lat, jittered_lng)` pair for the same `p_listing_id` on every call. Reordering, concurrent calls, or call frequency MUST NOT affect the output.
2. **Salt dependency**: The function reads `current_setting('app.map_jitter_salt')`. If the GUC is unset or empty, the function MUST raise `EXCEPTION 'app.map_jitter_salt is not set; Phase 15 setup incomplete'`.
3. **Salt rotation**: Re-running `ALTER DATABASE postgres SET app.map_jitter_salt = '<new-hex>'` MUST cause every approximate listing's jitter output to change. (This is acceptable per FR-003 — the marker was always approximate.)
4. **Area centroid fallback**: When `p_original_lat` OR `p_original_lng` is null, the function MUST anchor on `(p_area.centroid_lat, p_area.centroid_lng)` (Phase 10 R-12) and jitter from there. If `p_area_id` resolves to no row OR the area has null centroids, raise `EXCEPTION 'area % missing centroid; cannot jitter', p_area_id`.
5. **Jitter radius**: The pre-clamp offset MUST be bounded by `±0.0045°` lat and `±0.0045°` lng (~500m at Syrian latitudes).
6. **Area-bounds clamp**: The post-jitter coordinates MUST be clamped to `±0.02°` around the area's centroid (`v_clamp_radius`). This guarantees the marker stays within ~2.2km of the area's center even when the listing's stored coords are far from the centroid.
7. **No PostGIS dependency**: The function MUST use only plain `numeric` arithmetic, `digest()` from `pgcrypto` (already enabled), and standard PL/pgSQL constructs.
8. **No side effects**: The function MUST NOT INSERT/UPDATE/DELETE any row. It MUST NOT write to any audit log. It is a pure read function.

## Permissions

- `REVOKE ALL ON FUNCTION ... FROM PUBLIC;`
- `GRANT EXECUTE ON FUNCTION ... TO authenticated, anon;`

## Idempotency

The migration uses `CREATE OR REPLACE FUNCTION`. Re-applying the migration overwrites the function body without dropping it. The `REVOKE` + `GRANT` statements are idempotent.

## Setup procedure (one-time)

```bash
SALT=$(openssl rand -hex 32)
psql "$SUPABASE_DB_URL" -c "ALTER DATABASE postgres SET app.map_jitter_salt = '$SALT';"
psql "$SUPABASE_DB_URL" -c "SELECT current_setting('app.map_jitter_salt');"
# Expected: the hex string set above
```

## Smoke test queries

```sql
-- Determinism: same listing returns same coords across calls
SELECT * FROM public.map_jitter_coordinates(
  '00000000-0000-0000-0000-000000000001'::uuid,
  (SELECT id FROM public.areas LIMIT 1),
  33.5138, 36.2765
);
SELECT * FROM public.map_jitter_coordinates(
  '00000000-0000-0000-0000-000000000001'::uuid,
  (SELECT id FROM public.areas LIMIT 1),
  33.5138, 36.2765
);
-- Expected: identical (lat, lng) pairs

-- Different listing IDs produce different offsets
SELECT * FROM public.map_jitter_coordinates(
  '00000000-0000-0000-0000-000000000001'::uuid,
  (SELECT id FROM public.areas LIMIT 1),
  33.5138, 36.2765
);
SELECT * FROM public.map_jitter_coordinates(
  '00000000-0000-0000-0000-000000000002'::uuid,
  (SELECT id FROM public.areas LIMIT 1),
  33.5138, 36.2765
);
-- Expected: different (lat, lng) pairs

-- Null lat/lng triggers area-centroid fallback
SELECT * FROM public.map_jitter_coordinates(
  '00000000-0000-0000-0000-000000000003'::uuid,
  (SELECT id FROM public.areas WHERE display_name->>'en' = 'Mezzeh'),
  NULL, NULL
);
-- Expected: jittered coords near Mezzeh centroid (within ±0.02°)

-- Unset salt raises
ALTER DATABASE postgres RESET app.map_jitter_salt;
SELECT * FROM public.map_jitter_coordinates(...);
-- Expected: ERROR "app.map_jitter_salt is not set; Phase 15 setup incomplete"
-- (Restore the salt before continuing)
```
