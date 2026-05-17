# Contract: Phase 8 Tables

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [../plan.md](../plan.md) | **Data model**: [../data-model.md](../data-model.md) §1

## Required tables

The Phase 8 implementation MUST create three tables in the `public` schema with the column shapes, constraints, and RLS state codified in `data-model.md §1`. The deliverable is verified by:

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema='public' AND table_name IN ('governorates','cities','areas')
ORDER BY table_name;
-- Expected: areas, cities, governorates (3 rows).
```

## Per-table column shape contract

All three tables MUST carry:

- `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`
- `key TEXT NOT NULL` with the CHECK constraint `key ~ '^[a-z0-9][a-z0-9-]*$'` (lowercase slug)
- `display_name JSONB NOT NULL` with the CHECK that the value is a JSON object AND `display_name->>'ar'` (trimmed) is non-empty (FR-016 Arabic-first; Constitution V)
- `description JSONB NULL`
- `position INTEGER NULL`
- `is_active BOOLEAN NOT NULL DEFAULT true`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()` (maintained by Phase 4 `set_updated_at` trigger)

Additionally:

- `public.governorates` carries `is_system BOOLEAN NOT NULL DEFAULT false` AND `UNIQUE(key)` at the column level.
- `public.cities` carries `is_system BOOLEAN NOT NULL DEFAULT false` AND `governorate_id UUID NOT NULL REFERENCES public.governorates(id) ON DELETE CASCADE` AND `UNIQUE(governorate_id, key)` as a composite constraint.
- `public.areas` does NOT carry `is_system`. It carries `city_id UUID NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE` AND `UNIQUE(city_id, key)` as a composite constraint.

Verification SQL (representative; per-column iteration suffices for full validation):

```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='governorates'
ORDER BY ordinal_position;

SELECT conname, contype, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.cities'::regclass;
```

## RLS state contract

All three tables MUST have RLS enabled:

```sql
SELECT relname, relrowsecurity
FROM pg_class
WHERE relname IN ('governorates','cities','areas') AND relnamespace = 'public'::regnamespace;
-- Expected: every row has relrowsecurity = TRUE.
```

## Migration ordering contract

The three table-creation migrations MUST apply in this order:

1. `20260517120001_create_governorates.sql` first (no FK dependencies).
2. `20260517120002_create_cities.sql` second (FK references `governorates`).
3. `20260517120003_create_areas.sql` third (FK references `cities`).
4. `20260517120004_create_locations_indexes.sql` fourth (depends on all three tables existing).
5. `20260517120005_phase8_advisor_hardening.sql` last (defense-in-depth pass).

Each migration MUST be idempotent: `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, `DROP TRIGGER IF EXISTS ... CREATE TRIGGER`, `DROP POLICY IF EXISTS ... CREATE POLICY`, and seed `INSERT ... ON CONFLICT DO NOTHING`. Re-applying any migration MUST produce zero net schema or data changes.

## Constitution traceability

- Constitution III (Security-First Supabase): RLS enabled on every table.
- Constitution VII (Dynamic Roles & Permissions): no hardcoded role checks in the table definitions; writes are gated by `current_user_has_permission('locations.manage')` (see `phase8-rls-policies.md`).
- Phase 4 R-05 invariant: `set_updated_at` reused unchanged across all three tables.
