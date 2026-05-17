# Contract: Phase 8 Audit Triggers

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [../plan.md](../plan.md) | **Data model**: [../data-model.md](../data-model.md) §3.4

## Required triggers

The implementation MUST attach nine audit triggers — three (INSERT/UPDATE/DELETE) per table — invoking Phase 4's `public.log_audit()` function unchanged (Phase 4 R-05 reusability invariant preserved a **fifth** time).

| Trigger name | Table | Event | `log_audit` action key | `log_audit` columns | `log_audit` target column |
|---|---|---|---|---|---|
| `trg_governorates_audit_created` | `public.governorates` | `AFTER INSERT` | `governorate.created` | `*` | `id` |
| `trg_governorates_audit_updated` | `public.governorates` | `AFTER UPDATE` | `governorate.updated` | `*` | `id` |
| `trg_governorates_audit_deleted` | `public.governorates` | `AFTER DELETE` | `governorate.deleted` | `*` | `id` |
| `trg_cities_audit_created` | `public.cities` | `AFTER INSERT` | `city.created` | `*` | `id` |
| `trg_cities_audit_updated` | `public.cities` | `AFTER UPDATE` | `city.updated` | `*` | `id` |
| `trg_cities_audit_deleted` | `public.cities` | `AFTER DELETE` | `city.deleted` | `*` | `id` |
| `trg_areas_audit_created` | `public.areas` | `AFTER INSERT` | `area.created` | `*` | `id` |
| `trg_areas_audit_updated` | `public.areas` | `AFTER UPDATE` | `area.updated` | `*` | `id` |
| `trg_areas_audit_deleted` | `public.areas` | `AFTER DELETE` | `area.deleted` | `*` | `id` |

## Ordering contract: triggers attached BEFORE seed (Clarifications Q5)

Within each table-creation migration, the audit triggers MUST be attached before the seed `INSERT` statements run. The exact ordering within `20260517120001_create_governorates.sql` is:

1. `CREATE TABLE`.
2. `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`.
3. `CREATE TRIGGER trg_governorates_set_updated_at ...`.
4. `CREATE TRIGGER trg_governorates_enforce_immutability ...` (governorates and cities only).
5. **`CREATE TRIGGER trg_governorates_audit_created/updated/deleted ...`** ← audit triggers here.
6. `CREATE POLICY ...` (SELECT + write).
7. `INSERT INTO public.governorates (...) VALUES (...), (...), ... ON CONFLICT (key) DO NOTHING;` ← seed inserts.

The seed produces exactly one `*.created` audit row per inserted row, with `actor_user_id = NULL` (the migration runs as `postgres`, which carries no `auth.uid()`).

## Function signature reuse

The `log_audit()` trigger function from Phase 4 is reused unchanged. Phase 8 MUST NOT modify the function body, return type, search-path posture, or SECURITY DEFINER posture. The trigger declarations pass the action name as `TG_ARGV[0]`, `'*'` as `TG_ARGV[1]`, and `'id'` as `TG_ARGV[2]`.

## Verification

```sql
-- Trigger presence
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table IN ('governorates','cities','areas')
  AND trigger_name LIKE 'trg_%_audit_%'
ORDER BY event_object_table, event_manipulation;
-- Expected: 9 rows (3 tables × 3 events).

-- Seed produced audit rows
SELECT action, COUNT(*) FROM public.audit_logs
WHERE action IN ('governorate.created','city.created','area.created')
  AND actor_user_id IS NULL
GROUP BY action
ORDER BY action;
-- Expected after seed: governorate.created=14, city.created=30..40, area.created=N (seed inventory).

-- Live mutation test (per US7 Independent Test)
INSERT INTO public.governorates (key, display_name) VALUES ('test-aud', '{"ar":"اختبار","en":"Test"}');
SELECT action, actor_user_id, target_id FROM public.audit_logs WHERE action='governorate.created' ORDER BY occurred_at DESC LIMIT 1;
DELETE FROM public.governorates WHERE key='test-aud';
```

## Constitution traceability

- Constitution VII (Dynamic Roles & Permissions): audit emission is universal for the role/permission/locations graph; Phase 8 closes the locations gap.
- Phase 4 R-05: `log_audit()` is unchanged for a fifth time across Phases 4/5/6/7/8.
