# Table: `governorates`

Added in Phase 8 (`20260517120001_create_governorates.sql`).

## Purpose

Stores the catalog of Syrian first-level administrative divisions (14 governorates). The rows are seeded with `is_system=true` and are globally readable by anonymous and authenticated users (FR-001, FR-004). Write access requires the `locations.manage` permission (FR-009).

## Schema

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `id` | UUID | `gen_random_uuid()` | Primary key |
| `key` | TEXT | — | Stable lowercase slug (e.g. `damascus`, `rif-dimashq`). `UNIQUE NOT NULL`. Immutable for `is_system=true` rows (trigger-enforced). Format: `^[a-z0-9][a-z0-9-]*$` |
| `display_name` | JSONB | — | `NOT NULL`. Bilingual: `{"ar": "...", "en": "..."}`. Arabic value required. Phase 6 `roles.display_name` pattern. |
| `description` | JSONB | NULL | Optional bilingual notes. |
| `position` | INTEGER | NULL | Editorial ordering hint. `ORDER BY position NULLS LAST, key ASC`. |
| `is_active` | BOOLEAN | `true` | Soft-deactivation. Admin pages show inactive rows with a Hidden badge; LocationPicker filters them out. |
| `is_system` | BOOLEAN | `false` | `true` for all 14 seeded governorates. Blocks DELETE and `key` UPDATE via trigger. |
| `created_at` | TIMESTAMPTZ | `now()` | Set at insert. |
| `updated_at` | TIMESTAMPTZ | `now()` | Maintained by `trg_governorates_set_updated_at` BEFORE UPDATE trigger. |

## RLS Posture

RLS enabled. Four policies (FR-009, R-04, R-16):

| Operation | Policy | Gating condition |
|-----------|--------|-----------------|
| SELECT | `governorates_select_public` | `anon` AND `authenticated` — explicit anonymous carve-out (global reference data per R-04) |
| INSERT | `governorates_insert_locations_manage` | `authenticated` + `current_user_has_permission('locations.manage')` |
| UPDATE | `governorates_update_locations_manage` | `authenticated` + `current_user_has_permission('locations.manage')` |
| DELETE | `governorates_delete_locations_manage` | `authenticated` + `current_user_has_permission('locations.manage')` |

Mirrored to [`supabase/policies/governorates_phase8.sql`](../policies/governorates_phase8.sql) (R-02 dual-storage invariant).

## Triggers

- `trg_governorates_set_updated_at` — BEFORE UPDATE, calls `set_updated_at()` (Phase 4 helper).
- `trg_governorates_enforce_immutability` — BEFORE UPDATE OR DELETE, calls `enforce_governorate_system_immutability()`. Raises SQLSTATE `42501` if:
  - `TG_OP = 'DELETE'` and `OLD.is_system = true`
  - `TG_OP = 'UPDATE'` and `OLD.is_system = true` and `NEW.key IS DISTINCT FROM OLD.key`
  - Updates to `display_name`, `description`, `position`, or `is_active` on system rows are **allowed**.
- `trg_governorates_audit_created` — AFTER INSERT, emits `audit_logs.action = 'governorate.created'`.
- `trg_governorates_audit_updated` — AFTER UPDATE, emits `audit_logs.action = 'governorate.updated'`.
- `trg_governorates_audit_deleted` — AFTER DELETE, emits `audit_logs.action = 'governorate.deleted'`.

Trigger count: 5. Audit triggers call Phase 4's reusable `log_audit('governorate.*', '*', 'id')` function (5th reuse, R-13).

## Seeded System Rows (14 rows, `is_system=true`)

Seeded by the migration via `INSERT ... ON CONFLICT (key) DO NOTHING`. Triggers attached BEFORE seed so every row produces one `governorate.created` audit row with `actor_user_id=NULL` (Clarifications Q5, R-08).

| `key` | `display_name.ar` | `display_name.en` | `position` |
|---|---|---|---|
| `damascus` | دمشق | Damascus | 10 |
| `aleppo` | حلب | Aleppo | 20 |
| `homs` | حمص | Homs | 30 |
| `latakia` | اللاذقية | Latakia | 40 |
| `tartus` | طرطوس | Tartus | 50 |
| `hama` | حماة | Hama | 60 |
| `rif-dimashq` | ريف دمشق | Rif Dimashq | 70 |
| `idlib` | إدلب | Idlib | 80 |
| `daraa` | درعا | Daraa | 90 |
| `deir-ez-zor` | دير الزور | Deir ez-Zor | 100 |
| `al-hasakah` | الحسكة | Al-Hasakah | 110 |
| `al-raqqah` | الرقة | Al-Raqqah | 120 |
| `as-suwayda` | السويداء | As-Suwayda | 130 |
| `quneitra` | القنيطرة | Quneitra | 140 |

## Cross-References

- Spec FRs: FR-001, FR-004, FR-007, FR-008, FR-009
- Contracts: `specs/008-locations/contracts/phase8-tables.md`, `contracts/phase8-rls-policies.md`, `contracts/phase8-immutability-triggers.md`
- Downstream: `cities.governorate_id` FK with `ON DELETE CASCADE` (Clarifications Q2)
- Forward: Phase 10 `listings.city_id` / `area_id` FKs use `ON DELETE RESTRICT` / `SET NULL` — Phase 8 CASCADE never silently removes listing rows
