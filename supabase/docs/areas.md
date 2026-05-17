# Table: `areas`

Added in Phase 8 (`20260517120003_create_areas.sql`).

## Purpose

Stores areas (neighbourhoods / districts) scoped to cities. A small starter set is seeded; admins fill the rest via the in-app form (US5). Areas are globally readable by anonymous and authenticated users. Write access requires the `locations.manage` permission (FR-009). Areas cascade-delete when their parent city is deleted (Clarifications Q2, FR-002, FR-006).

**Key difference from `governorates` and `cities`**: `areas` has **no `is_system` column** and **no immutability trigger**. Every area row is fully editable and deletable (Clarifications Q3).

## Schema

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `id` | UUID | `gen_random_uuid()` | Primary key |
| `city_id` | UUID | — | `NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE`. Scopes the area to a city. |
| `key` | TEXT | — | Stable lowercase slug, unique within the city. Format: `^[a-z0-9][a-z0-9-]*$`. Fully mutable — no immutability trigger. |
| `display_name` | JSONB | — | `NOT NULL`. Bilingual: `{"ar": "...", "en": "..."}`. Arabic value required. |
| `description` | JSONB | NULL | Optional bilingual notes. |
| `position` | INTEGER | NULL | Editorial ordering hint. `ORDER BY position NULLS LAST, key ASC` within the city. |
| `is_active` | BOOLEAN | `true` | Soft-deactivation. LocationPicker filters out inactive areas. |
| `created_at` | TIMESTAMPTZ | `now()` | Set at insert. |
| `updated_at` | TIMESTAMPTZ | `now()` | Maintained by `trg_areas_set_updated_at` BEFORE UPDATE trigger. |

**Unique constraint**: `(city_id, key)` — key uniqueness is scoped per city, not globally.

**Absent**: no `is_system` column. Attempting to add one would require a Phase 8+ follow-up migration and is out of scope.

## RLS Posture

RLS enabled. Four policies (FR-009, R-04, R-16):

| Operation | Policy | Gating condition |
|-----------|--------|-----------------|
| SELECT | `areas_select_public` | `anon` AND `authenticated` — explicit anonymous carve-out (global reference data per R-04) |
| INSERT | `areas_insert_locations_manage` | `authenticated` + `current_user_has_permission('locations.manage')` |
| UPDATE | `areas_update_locations_manage` | `authenticated` + `current_user_has_permission('locations.manage')` |
| DELETE | `areas_delete_locations_manage` | `authenticated` + `current_user_has_permission('locations.manage')` |

Mirrored to [`supabase/policies/areas_phase8.sql`](../policies/areas_phase8.sql) (R-02 dual-storage invariant).

## Triggers

- `trg_areas_set_updated_at` — BEFORE UPDATE, calls `set_updated_at()` (Phase 4 helper).
- `trg_areas_audit_created` — AFTER INSERT, emits `audit_logs.action = 'area.created'`.
- `trg_areas_audit_updated` — AFTER UPDATE, emits `audit_logs.action = 'area.updated'`.
- `trg_areas_audit_deleted` — AFTER DELETE, emits `audit_logs.action = 'area.deleted'`.

Trigger count: 4 (set_updated_at + 3 audit; **no immutability trigger**). Audit triggers call Phase 4's reusable `log_audit('area.*', '*', 'id')` function (5th reuse, R-13).

## Seeded Starter Rows (9 rows)

Seeded by `INSERT ... ON CONFLICT (city_id, key) DO NOTHING` with `city_id` resolved via nested subquery (`cities.key` + `governorates.key`). Triggers attached BEFORE seed so every row produces one `area.created` audit row with `actor_user_id=NULL` (Clarifications Q5, R-08).

One or more areas per the six major cities: Damascus (3), Aleppo (2), Homs (1), Latakia (1), Tartus (1), Hama (1). Admins add more via the US5 in-app form.

## Cross-References

- Spec FRs: FR-001, FR-002, FR-006, FR-007, FR-009
- Contracts: `specs/008-locations/contracts/phase8-tables.md`, `contracts/phase8-rls-policies.md`
- Parent: `cities.id` FK with `ON DELETE CASCADE` — deleting a city cascades to all its areas
- Forward: Phase 10 `listings.area_id` FK uses `ON DELETE SET NULL` (area is optional on a listing) — Phase 8 CASCADE never silently removes a listing; only the area reference becomes NULL
