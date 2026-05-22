# Contract: Altered Phase 8 `public.areas` — Centroid Columns

**Owner**: Phase 10, migration `20260519120001_alter_areas_add_centroids.sql`.
**Consumers**: Phase 10 listing form (location step's centroid auto-fill); Phase 15 map view (default pin placement); future Phase 8 admin-form extension.

## Obligations

Per Q2 (resolved Session 2026-05-18) + R-07 (area-centroid data-source path), Phase 10 extends Phase 8's `public.areas` table with two new columns and seeds them from manually-researched OpenStreetMap centroids.

1. `ALTER TABLE public.areas ADD COLUMN centroid_lat NUMERIC(9, 6)` (initially NULL).
2. `ALTER TABLE public.areas ADD COLUMN centroid_lng NUMERIC(9, 6)` (initially NULL).
3. UPDATE every existing area row with a researched centroid value from OpenStreetMap. The migration inlines the VALUES (~50–100 rows). Centroids are valid Syrian coordinates (lat 32–37, lng 35–43).
4. After the seed, the migration verifies zero missing-centroid rows and raises if any are missing.
5. `ALTER COLUMN ... SET NOT NULL` on both columns.
6. `ADD CONSTRAINT areas_centroid_syria_bounds CHECK (centroid_lat BETWEEN 32 AND 37 AND centroid_lng BETWEEN 35 AND 43)`.

## Verification

```sql
-- Both columns exist + are NOT NULL
SELECT column_name, is_nullable FROM information_schema.columns
WHERE table_schema='public' AND table_name='areas' AND column_name IN ('centroid_lat','centroid_lng');
-- Expected: 2 rows, both is_nullable=NO

-- Every existing area has centroids
SELECT count(*) FROM public.areas WHERE centroid_lat IS NULL OR centroid_lng IS NULL;
-- Expected: 0

-- Bounds constraint exists
SELECT constraint_name FROM information_schema.table_constraints
WHERE table_name='areas' AND constraint_name='areas_centroid_syria_bounds';
-- Expected: 1 row

-- Centroids fall in Syria's bounding box
SELECT count(*) FROM public.areas WHERE centroid_lat NOT BETWEEN 32 AND 37 OR centroid_lng NOT BETWEEN 35 AND 43;
-- Expected: 0
```

## Forbidden

- Allowing `NULL` values in `centroid_lat` or `centroid_lng` post-migration.
- Removing the `areas_centroid_syria_bounds` CHECK constraint.
- Sourcing centroids from a runtime geocoder lookup (R-07 alternatives rejected).
- Extending Phase 8's admin add-area form in Phase 10 (deferred — Phase 8 follow-up patch or future spec).
