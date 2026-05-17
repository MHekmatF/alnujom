# Contract: Phase 8 RLS Policies

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [../plan.md](../plan.md) | **Data model**: [../data-model.md](../data-model.md) §4

## Required policies — 12 total (4 per table × 3 tables)

| Policy name | Table | Operation | Role(s) | `USING` / `WITH CHECK` |
|---|---|---|---|---|
| `governorates_select_public`         | `governorates` | SELECT | `anon`, `authenticated` | `USING (true)` |
| `governorates_insert_locations_manage` | `governorates` | INSERT | `authenticated`         | `WITH CHECK (public.current_user_has_permission('locations.manage'))` |
| `governorates_update_locations_manage` | `governorates` | UPDATE | `authenticated`         | `USING / WITH CHECK (public.current_user_has_permission('locations.manage'))` |
| `governorates_delete_locations_manage` | `governorates` | DELETE | `authenticated`         | `USING (public.current_user_has_permission('locations.manage'))` |
| `cities_select_public`         | `cities` | SELECT | `anon`, `authenticated` | `USING (true)` |
| `cities_insert_locations_manage` | `cities` | INSERT | `authenticated`         | `WITH CHECK (public.current_user_has_permission('locations.manage'))` |
| `cities_update_locations_manage` | `cities` | UPDATE | `authenticated`         | `USING / WITH CHECK (public.current_user_has_permission('locations.manage'))` |
| `cities_delete_locations_manage` | `cities` | DELETE | `authenticated`         | `USING (public.current_user_has_permission('locations.manage'))` |
| `areas_select_public`         | `areas` | SELECT | `anon`, `authenticated` | `USING (true)` |
| `areas_insert_locations_manage` | `areas` | INSERT | `authenticated`         | `WITH CHECK (public.current_user_has_permission('locations.manage'))` |
| `areas_update_locations_manage` | `areas` | UPDATE | `authenticated`         | `USING / WITH CHECK (public.current_user_has_permission('locations.manage'))` |
| `areas_delete_locations_manage` | `areas` | DELETE | `authenticated`         | `USING (public.current_user_has_permission('locations.manage'))` |

## Anonymous SELECT carve-out (R-04, R-16)

The SELECT policies MUST admit the `anon` role. This is a deliberate departure from Constitution III's authenticated-only default, codified in:

- Spec Edge Cases ("Anonymous read on app launch")
- Research R-04 and R-16
- Migration comments above each SELECT policy
- The `20260517120005_phase8_advisor_hardening.sql` migration's explicit `GRANT SELECT ON public.governorates, public.cities, public.areas TO anon, authenticated;`

The deliberate posture is documented; Supabase advisors should not flag it as an accidental misconfiguration. The advisor-hardening migration runs `SELECT * FROM supabase.get_advisors()` (or the MCP equivalent) and verifies the relevant advisors are clean.

## `current_user_has_permission('locations.manage')` reuse

The Phase 6 helper `public.current_user_has_permission(TEXT)` is consumed unchanged (R-14). Phase 8 MUST NOT edit, drop, or recreate this function.

## Policy file mirror (R-02)

The 12 policies live in TWO places:

1. Inline within the three table-creation migrations (`20260517120001_create_governorates.sql`, `20260517120002_create_cities.sql`, `20260517120003_create_areas.sql`) — canonical applier.
2. Parallel `supabase/policies/governorates_phase8.sql`, `cities_phase8.sql`, `areas_phase8.sql` files — canonical documentation for reviewers and `/security-review`.

The SQL in both places MUST be identical; CI / PR review verifies the duplication.

## Verification

```sql
SELECT schemaname, tablename, policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname='public' AND tablename IN ('governorates','cities','areas')
ORDER BY tablename, cmd, policyname;
-- Expected: 12 rows total (4 per table).

-- Anonymous JWT (or no JWT): SELECT works, writes are 0-rows-affected
SET LOCAL ROLE anon;
SELECT count(*) FROM public.governorates;  -- expected: 14
INSERT INTO public.governorates (key, display_name) VALUES ('xx', '{"ar":"س"}');  -- expected: ERROR or 0 rows
RESET ROLE;

-- Authenticated JWT without locations.manage: SELECT works, writes are refused
-- (use a Phase 5 regular-user JWT via Supabase MCP execute_sql with the appropriate impersonation)
-- Expected: SELECT returns 14 rows; INSERT/UPDATE/DELETE returns 0 rows affected with RLS deny.

-- Authenticated JWT with locations.manage (admin): all operations succeed
-- Expected: SELECT works; INSERT inserts; UPDATE updates; DELETE deletes (subject to is_system trigger).
```

## Constitution traceability

- Constitution III (Security-First Supabase NON-NEGOTIABLE): RLS enabled + write-gated by permission key.
- Constitution VII (Dynamic Roles & Permissions): policies consult `current_user_has_permission(<key>)`, never hardcoded role checks.
