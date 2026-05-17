# Contract: Phase 8 System-Row Immutability Triggers

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [../plan.md](../plan.md) | **Data model**: [../data-model.md](../data-model.md) §3.2, §3.3

## Required triggers

Two new BEFORE-UPDATE-OR-DELETE triggers (Clarifications Session 2026-05-16 Q3):

| Trigger name | Table | Event | Function body source |
|---|---|---|---|
| `trg_governorates_enforce_immutability` | `public.governorates` | `BEFORE UPDATE OR DELETE` | `public.enforce_governorate_system_immutability()` |
| `trg_cities_enforce_immutability`       | `public.cities`       | `BEFORE UPDATE OR DELETE` | `public.enforce_city_system_immutability()` |

`public.areas` does NOT have an immutability trigger — areas have no `is_system` column and no protected seed.

## Function contract

Both functions are `LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth`. The function body MUST:

- On `DELETE`: if `OLD.is_system = true`, raise `EXCEPTION ... USING ERRCODE = '42501'` with message prefix `governorate_system_immutable:` (or `city_system_immutable:`) and the OLD row's `key` value embedded. Return `OLD`.
- On `UPDATE`: if `OLD.is_system = true` AND `NEW.key IS DISTINCT FROM OLD.key`, raise the same SQLSTATE `42501` with message prefix `governorate_system_immutable:` (or `city_system_immutable:`) noting the old vs attempted new key. Return `NEW`.
- On all other paths (DELETE on `is_system=false`; UPDATE on `is_system=false`; UPDATE on `is_system=true` that does NOT change `key`): return without raising.

The functions MUST NOT block UPDATEs on `display_name`, `description`, `position`, or `is_active` even when `is_system=true` — these are legitimate edits (renaming, deactivating, reordering).

## Pattern source

Mirrors Phase 6's `public.enforce_role_system_immutability()` function exactly. The Phase 6 trigger source is in `supabase/migrations/20260515120001_create_roles.sql`; Phase 8 implementers SHOULD use it as the template.

## Defense-in-depth contract

Even when reached through Supabase MCP `execute_sql` running with an admin JWT, the triggers MUST refuse the protected operations. Verification:

```sql
-- Bootstrap (assumes seed is in place)
SELECT id, key, is_system FROM public.governorates WHERE key='damascus';
-- Expected: is_system=true.

-- Refused DELETE
DELETE FROM public.governorates WHERE key='damascus';
-- Expected: ERROR 42501 governorate_system_immutable: cannot delete a system governorate (key=damascus)

-- Refused key UPDATE
UPDATE public.governorates SET key='dimashq' WHERE key='damascus';
-- Expected: ERROR 42501 governorate_system_immutable: cannot rename a system governorate's key

-- Allowed UPDATE on display_name
UPDATE public.governorates SET display_name = display_name || '{"fr":"Damas"}'::jsonb WHERE key='damascus';
-- Expected: 1 row updated, no error.

-- Allowed UPDATE on is_active (deactivation)
UPDATE public.governorates SET is_active = false WHERE key='damascus';
UPDATE public.governorates SET is_active = true  WHERE key='damascus'; -- restore.
-- Expected: both succeed.
```

## UI-side mirror contract

The Flutter admin pages MUST hide the Delete affordance and the `key`-rename affordance on `is_system=true` rows so the admin never sees an affordance that would error (FR-015). The trigger is defense-in-depth, not the only line of defense.

## Constitution traceability

- Constitution III (Security-First Supabase NON-NEGOTIABLE): defense-in-depth via DB triggers.
- Constitution XII (No Hidden Product Decisions): the immutability choice and its rationale are recorded in spec Assumptions and in research R-07.
