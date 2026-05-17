# Contract: Phase 8 Seed Inventory

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [../plan.md](../plan.md) | **Data model**: [../data-model.md](../data-model.md) §5

## Required seed rows

The Phase 8 implementation MUST seed the following rows during the table-creation migrations. The exact inventory is codified in `data-model.md §5`; this contract enumerates the floor — the implementer MAY add 1–2 additional cities or areas to reach the upper end of the 30–40 city target band, but MUST NOT subtract from the floor.

### Governorates — exactly 14 rows, `is_system=true`

Floor / ceiling = same: 14 rows. Keys: `damascus`, `aleppo`, `homs`, `latakia`, `tartus`, `hama`, `rif-dimashq`, `idlib`, `daraa`, `deir-ez-zor`, `al-hasakah`, `al-raqqah`, `as-suwayda`, `quneitra`. Each row has bilingual `display_name`, a non-null `position` value (10, 20, 30, ..., 140 in the order listed), `is_active=true`, `is_system=true`.

### Cities — target 30–40 rows, all `is_system=true`

Floor: 14 seat cities (one per governorate, matching the `key` of the governorate itself; e.g., the city `damascus` under governorate `damascus`). Seat cities carry `position=10`.

Ceiling: ~40 rows. The second-tier additions per `data-model.md §5.2` bring the total to 32 in the planned inventory. The implementer MAY shrink the second-tier list slightly if a bilingual name proves non-canonical or expand it slightly if additional well-known cities are requested by the project owner at PR review time, within the 30–40 band.

### Areas — starter set, no `is_system`

Floor: at least one area in each of the six named major-city rows (Damascus, Aleppo, Homs, Latakia, Tartus, Hama). Ceiling: ~10 areas total. Areas carry `is_active=true`, no `is_system`, optional `position`. The migration MAY add or omit areas as long as the floor is met.

## Idempotency contract

Every seed `INSERT` MUST use the appropriate `ON CONFLICT ... DO NOTHING` clause:

```sql
INSERT INTO public.governorates (key, display_name, position, is_system, is_active)
VALUES
  ('damascus',    '{"ar":"دمشق","en":"Damascus"}',          10, true, true),
  ('aleppo',      '{"ar":"حلب","en":"Aleppo"}',             20, true, true),
  -- ... 12 more rows ...
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.cities (governorate_id, key, display_name, position, is_system, is_active)
VALUES
  ((SELECT id FROM public.governorates WHERE key='damascus'),
   'damascus', '{"ar":"دمشق","en":"Damascus"}', 10, true, true),
  -- ... more rows ...
ON CONFLICT (governorate_id, key) DO NOTHING;

INSERT INTO public.areas (city_id, key, display_name, is_active)
VALUES
  ((SELECT id FROM public.cities WHERE key='damascus' AND governorate_id=(SELECT id FROM public.governorates WHERE key='damascus')),
   'old-city-damascus', '{"ar":"المدينة القديمة","en":"Old City Damascus"}', true),
  -- ... more rows ...
ON CONFLICT (city_id, key) DO NOTHING;
```

Re-applying any of the three migrations MUST insert zero additional rows (the migration is a no-op on a project that already has the seed).

## Audit-row coverage contract

Per R-08, the audit triggers attach BEFORE the seed `INSERT`s. The seed therefore produces:

- 14 `audit_logs` rows with `action='governorate.created'`, `actor_user_id=NULL`
- 30–40 rows with `action='city.created'`, `actor_user_id=NULL`
- ~6–10 rows with `action='area.created'`, `actor_user_id=NULL`

Total: ~50–64 rows from the initial seed. Verification:

```sql
SELECT action, COUNT(*)
FROM public.audit_logs
WHERE action IN ('governorate.created','city.created','area.created') AND actor_user_id IS NULL
GROUP BY action;
```

## Canonical Arabic names

Constitution V mandates Syrian-friendly Arabic. The migration author MUST verify each `display_name->>'ar'` value against the canonical Syrian public-discourse form (e.g., "دمشق" not "الشام"; "ريف دمشق" exact form; "اللاذقية" with the leading definite article). The English values use widely-recognized transliterations.

## Verification SQL

```sql
SELECT count(*) FROM public.governorates;                                          -- expected: 14
SELECT count(*) FROM public.governorates WHERE is_system;                          -- expected: 14
SELECT count(*) FROM public.cities;                                                -- expected: 30..40
SELECT count(*) FROM public.cities WHERE is_system;                                -- expected: 30..40
SELECT count(*) FROM public.areas;                                                 -- expected: 1..10 (depending on inventory)
SELECT key FROM public.governorates WHERE display_name->>'ar' IS NULL OR trim(display_name->>'ar') = ''; -- expected: 0 rows
SELECT key FROM public.cities       WHERE display_name->>'ar' IS NULL OR trim(display_name->>'ar') = ''; -- expected: 0 rows
SELECT key FROM public.areas        WHERE display_name->>'ar' IS NULL OR trim(display_name->>'ar') = ''; -- expected: 0 rows
SELECT count(*) FROM public.governorates WHERE display_name->>'en' IS NULL OR trim(display_name->>'en') = ''; -- SHOULD be 0 (English coverage for bilingual baseline)
```

## Constitution traceability

- Constitution V (Arabic-First Localization): every seeded row has a canonical Syrian Arabic name.
- Constitution XII (No Hidden Product Decisions): the 30–40 city target is recorded in spec Clarifications Q4.
