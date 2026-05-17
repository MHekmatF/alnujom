# Table: `cities`

Added in Phase 8 (`20260517120002_create_cities.sql`).

## Purpose

Stores cities scoped to governorates (~32 seeded with `is_system=true` per Clarifications Q4). Globally readable by anonymous and authenticated users. Write access requires the `locations.manage` permission (FR-009). Cities cascade-delete when their parent governorate is deleted (Clarifications Q2, FR-002, FR-005).

## Schema

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `id` | UUID | `gen_random_uuid()` | Primary key |
| `governorate_id` | UUID | — | `NOT NULL REFERENCES public.governorates(id) ON DELETE CASCADE`. Scopes the city to a governorate. |
| `key` | TEXT | — | Stable lowercase slug, unique within the governorate. Format: `^[a-z0-9][a-z0-9-]*$`. Immutable for `is_system=true` rows. |
| `display_name` | JSONB | — | `NOT NULL`. Bilingual: `{"ar": "...", "en": "..."}`. Arabic value required. |
| `description` | JSONB | NULL | Optional bilingual notes. |
| `position` | INTEGER | NULL | Editorial ordering hint. `ORDER BY position NULLS LAST, key ASC` within the governorate. |
| `is_active` | BOOLEAN | `true` | Soft-deactivation. LocationPicker filters out inactive cities. |
| `is_system` | BOOLEAN | `false` | `true` for all 32 seeded cities. Blocks DELETE and `key` UPDATE via trigger. |
| `created_at` | TIMESTAMPTZ | `now()` | Set at insert. |
| `updated_at` | TIMESTAMPTZ | `now()` | Maintained by `trg_cities_set_updated_at` BEFORE UPDATE trigger. |

**Unique constraint**: `(governorate_id, key)` — key uniqueness is scoped per governorate, not globally.

## RLS Posture

RLS enabled. Four policies (FR-009, R-04, R-16):

| Operation | Policy | Gating condition |
|-----------|--------|-----------------|
| SELECT | `cities_select_public` | `anon` AND `authenticated` — explicit anonymous carve-out (global reference data per R-04) |
| INSERT | `cities_insert_locations_manage` | `authenticated` + `current_user_has_permission('locations.manage')` |
| UPDATE | `cities_update_locations_manage` | `authenticated` + `current_user_has_permission('locations.manage')` |
| DELETE | `cities_delete_locations_manage` | `authenticated` + `current_user_has_permission('locations.manage')` |

Mirrored to [`supabase/policies/cities_phase8.sql`](../policies/cities_phase8.sql) (R-02 dual-storage invariant).

## Triggers

- `trg_cities_set_updated_at` — BEFORE UPDATE, calls `set_updated_at()` (Phase 4 helper).
- `trg_cities_enforce_immutability` — BEFORE UPDATE OR DELETE, calls `enforce_city_system_immutability()`. Raises SQLSTATE `42501` if:
  - `TG_OP = 'DELETE'` and `OLD.is_system = true`
  - `TG_OP = 'UPDATE'` and `OLD.is_system = true` and `NEW.key IS DISTINCT FROM OLD.key`
  - Updates to `display_name`, `description`, `position`, or `is_active` on system rows are **allowed**.
- `trg_cities_audit_created` — AFTER INSERT, emits `audit_logs.action = 'city.created'`.
- `trg_cities_audit_updated` — AFTER UPDATE, emits `audit_logs.action = 'city.updated'`.
- `trg_cities_audit_deleted` — AFTER DELETE, emits `audit_logs.action = 'city.deleted'`.

Trigger count: 5. Audit triggers call Phase 4's reusable `log_audit('city.*', '*', 'id')` function (5th reuse, R-13).

## Seeded System Rows (32 rows, `is_system=true`)

Seeded by `INSERT ... ON CONFLICT (governorate_id, key) DO NOTHING` with `governorate_id` resolved via subquery on `public.governorates.key`. Triggers attached BEFORE seed so every row produces one `city.created` audit row with `actor_user_id=NULL` (Clarifications Q5, R-08).

32 cities covering all 14 governorates (14 seat cities + second-tier coverage per Clarifications Q4). See `data-model.md § 5.2` for the full inventory.

## Cross-References

- Spec FRs: FR-001, FR-002, FR-005, FR-007, FR-008, FR-009
- Contracts: `specs/008-locations/contracts/phase8-tables.md`, `contracts/phase8-rls-policies.md`, `contracts/phase8-immutability-triggers.md`
- Parent: `governorates.id` FK with `ON DELETE CASCADE` — deleting a governorate cascades to all its cities (and transitively to all areas)
- Downstream: `areas.city_id` FK with `ON DELETE CASCADE` (Clarifications Q2)
- Forward: Phase 10 `listings.city_id` FK uses `ON DELETE RESTRICT` — Phase 8 CASCADE never silently removes listing rows
