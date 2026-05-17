# Quickstart: Phase 8 Locations Catalog Verification

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [plan.md](plan.md) | **Spec**: [spec.md](spec.md)

This file is the end-to-end manual-verification recipe for Phase 8. A reviewer or new agent can run these steps against the remote Supabase project + a Flutter device walk on the reference Infinix Note 8 and verify that every FR and SC is satisfied. No automated tests are introduced (per the durable `feedback_no_new_tests.md` rule); all verification is Supabase MCP `execute_sql` / `get_advisors` calls + device-walk actions.

## Prerequisites

- Local clone of the repo at `008-locations` branch with the Phase 8 migrations and Flutter code in place.
- Access to the remote Supabase project via Supabase MCP (`apply_migration`, `execute_sql`, `list_migrations`, `get_advisors`).
- The reference Infinix Note 8 device connected via `adb` with a Flutter Android build running.
- At least one Phase 5 admin account (carries the Phase 6 `admin` role; `locations.manage` is in the §9.1 mapping).
- A Phase 5 regular `user`-only test account (no admin tier).
- Optional: a Phase 5 moderator test account (admin tier but no `locations.manage`).

## Step 1 — Apply migrations

Run via Supabase MCP `apply_migration` in order:

1. `20260517120001_create_governorates.sql`
2. `20260517120002_create_cities.sql`
3. `20260517120003_create_areas.sql`
4. `20260517120004_create_locations_indexes.sql`
5. `20260517120005_phase8_advisor_hardening.sql`

After each migration, run `supabase__list_migrations` to confirm a new tracker row appeared and run `supabase__get_advisors` to confirm no new security / performance warnings introduced by Phase 8. The advisor-hardening migration (step 5) explicitly issues `GRANT SELECT ON ... TO anon, authenticated` so the anonymous-read policies are codified.

## Step 2 — Verify schema state

```sql
-- Tables exist with RLS enabled
SELECT relname, relrowsecurity
FROM pg_class
WHERE relname IN ('governorates','cities','areas') AND relnamespace = 'public'::regnamespace;
-- Expected: 3 rows; relrowsecurity = TRUE on every row.

-- Column shapes — spot-check governorates
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema='public' AND table_name='governorates'
ORDER BY ordinal_position;
-- Expected columns: id (uuid, NO), key (text, NO), display_name (jsonb, NO), description (jsonb, YES),
--                   position (integer, YES), is_active (boolean, NO), is_system (boolean, NO),
--                   created_at (timestamptz, NO), updated_at (timestamptz, NO)

-- Triggers (9 audit + 3 set_updated_at + 2 immutability = 14)
SELECT trigger_name, event_object_table, event_manipulation
FROM information_schema.triggers
WHERE event_object_schema='public'
  AND event_object_table IN ('governorates','cities','areas')
ORDER BY event_object_table, trigger_name;
-- Expected: 14 trigger rows.

-- Policies — 4 per table × 3 tables = 12
SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname='public' AND tablename IN ('governorates','cities','areas')
ORDER BY tablename, cmd;
-- Expected: 12 rows.
```

## Step 3 — Verify seed inventory (FR-004/005/006, SC-001/002/003/004/011)

```sql
SELECT count(*) FROM public.governorates;                 -- expected: 14 (SC-001)
SELECT count(*) FROM public.governorates WHERE is_system; -- expected: 14
SELECT count(*) FROM public.cities;                       -- expected: 30..40 (SC-002)
SELECT count(*) FROM public.cities WHERE is_system;       -- expected: 30..40
SELECT count(*) FROM public.areas;                        -- expected: 1..10 starter seed (SC-003)

-- Damascus + 5 named cities are present (plan headline)
SELECT key FROM public.cities WHERE key IN ('damascus','aleppo','homs','latakia','tartus','hama') ORDER BY key;
-- Expected: 6 rows.

-- Every seeded row has bilingual coverage (SC-004)
SELECT key FROM public.governorates WHERE coalesce(trim(display_name->>'ar'),'') = '' OR coalesce(trim(display_name->>'en'),'') = '';
-- Expected: 0 rows.
SELECT key FROM public.cities WHERE coalesce(trim(display_name->>'ar'),'') = '' OR coalesce(trim(display_name->>'en'),'') = '';
-- Expected: 0 rows.
```

## Step 4 — Verify audit-row coverage (FR-007, SC-013, R-08)

```sql
-- Initial-seed audit burst (Clarifications Q5)
SELECT action, count(*) FROM public.audit_logs
WHERE action IN ('governorate.created','city.created','area.created')
  AND actor_user_id IS NULL
GROUP BY action ORDER BY action;
-- Expected:
--   area.created         = N (matches the starter areas count)
--   city.created         = 30..40
--   governorate.created  = 14

-- No stray audit rows from before the seed
SELECT count(*) FROM public.audit_logs
WHERE action LIKE 'governorate.%' OR action LIKE 'city.%' OR action LIKE 'area.%';
-- Expected: matches the total seed row count exactly.
```

## Step 5 — Verify anonymous SELECT carve-out (FR-009, SC-005, R-04)

Using an anonymous Supabase JWT (or no JWT, depending on the MCP tooling):

```sql
SET LOCAL ROLE anon;
SELECT count(*) FROM public.governorates;  -- expected: 14
SELECT count(*) FROM public.cities;        -- expected: 30..40
SELECT count(*) FROM public.areas;         -- expected: 1..10
-- Write attempt fails:
INSERT INTO public.governorates (key, display_name) VALUES ('hack', '{"ar":"اختراق"}');
-- Expected: 0 rows affected (RLS deny).
RESET ROLE;
```

## Step 6 — Verify permission-gated writes (FR-008, SC-010)

Using a moderator JWT (no `locations.manage`):

```sql
-- Replace <moderator-jwt> with the actual JWT from Supabase Studio or a Phase 6 generated token.
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub TO '<moderator-uuid>';
INSERT INTO public.governorates (key, display_name) VALUES ('test-no', '{"ar":"اختبار"}');
-- Expected: 0 rows affected (RLS deny).
RESET ROLE;
```

Using an admin JWT (with `locations.manage`):

```sql
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub TO '<admin-uuid>';
INSERT INTO public.governorates (key, display_name) VALUES ('test-yes', '{"ar":"اختبار يعمل","en":"Test works"}') RETURNING id;
-- Expected: 1 row inserted.
UPDATE public.governorates SET display_name = display_name || '{"en":"Test works 2"}'::jsonb WHERE key='test-yes';
-- Expected: 1 row updated.
DELETE FROM public.governorates WHERE key='test-yes';
-- Expected: 1 row deleted.
RESET ROLE;
```

Verify the audit trail captured all three:

```sql
SELECT action, actor_user_id, target_id FROM public.audit_logs
WHERE action LIKE 'governorate.%' AND actor_user_id = '<admin-uuid>'
ORDER BY occurred_at DESC LIMIT 3;
-- Expected: governorate.deleted, governorate.updated, governorate.created (newest first).
```

## Step 7 — Verify system-row immutability (FR-007a, SC-017, Clarifications Q3)

Using the admin JWT (has `locations.manage`):

```sql
-- Attempt DELETE on a seeded (is_system=true) row
DELETE FROM public.governorates WHERE key='damascus';
-- Expected: ERROR 42501 governorate_system_immutable: cannot delete a system governorate (key=damascus)

-- Attempt key UPDATE on a seeded row
UPDATE public.governorates SET key='dimashq' WHERE key='damascus';
-- Expected: ERROR 42501 governorate_system_immutable: cannot rename a system governorate's key

-- Allowed UPDATE on display_name
UPDATE public.governorates SET display_name = display_name || '{"en":"Damascus 2"}'::jsonb WHERE key='damascus';
SELECT display_name->>'en' FROM public.governorates WHERE key='damascus';
-- Expected: "Damascus 2"
-- Restore:
UPDATE public.governorates SET display_name = display_name || '{"en":"Damascus"}'::jsonb WHERE key='damascus';

-- Allowed deactivation
UPDATE public.governorates SET is_active = false WHERE key='damascus';
SELECT is_active FROM public.governorates WHERE key='damascus';
-- Expected: false. Restore:
UPDATE public.governorates SET is_active = true WHERE key='damascus';
```

## Step 8 — Device walk: admin home tile gating (FR-012, FR-013, SC-008, SC-009)

1. Build and run the Flutter app on the Infinix Note 8 with `--dart-define-from-file=.env.json` (per project memory `project_dart_defines.md`).
2. Sign in as the regular `user`-only account. Confirm the admin home is not reachable (no admin tier at all).
3. Sign out, sign in as the moderator. Confirm the admin home renders but the Locations tile is absent. Hand-type `/admin/locations` into the router (via the deep-link affordance Phase 6 / Phase 7 already supports). Confirm the redirect refuses navigation.
4. Sign out, sign in as the admin. Confirm the admin home renders with the Locations tile present. Tap it. Confirm `LocationsListPage` opens listing all 14 governorates.

## Step 9 — Device walk: governorate CRUD (US3, FR-014/015/016/017, SC-006/007/016/017/021)

From the admin device on `LocationsListPage`:

1. Tap "Add governorate". Fill `key=test-gov`, `display_name.ar=اختبار`, `display_name.en=Test`. Tap Save. Confirm the new row appears in the list (alphabetical position by `key`).
2. Tap the new row → tap Edit. Change English name to "Test 2". Save. Confirm the row label updates immediately.
3. Long-press / open contextual menu on the new (`is_system=false`) row. Confirm Edit, Deactivate, Delete affordances are all present.
4. Long-press / open contextual menu on any of the 14 seeded (`is_system=true`) governorates (e.g., Damascus). Confirm Edit and Deactivate are present; **confirm Delete is absent**.
5. Toggle locale to English from the app settings or the system locale switcher. Confirm all 14 governorate names re-render in English (Damascus, Aleppo, ...). Toggle back to Arabic.
6. Edit Damascus's English name to "Damascus Capital". Save. From the smoke-test surface (or via the LocationPicker on the listing form when Phase 10 ships), confirm the new English name renders on next view.
7. Delete the test-gov row. Confirm the delete dialog appears, the row disappears from the list.

## Step 10 — Device walk: city + area CRUD (US4, US5, SC-011)

1. Tap Damascus in `LocationsListPage`. Confirm `GovernorateDetailPage` opens with the seeded Damascus cities listed.
2. Tap "Add city". Fill `key=jaramana`, bilingual name, save. Confirm the row appears.
3. Tap the new city. Tap "Add area". Fill `key=jaramana-center`, bilingual name, save. Confirm the area appears.
4. Verify via SQL:
   ```sql
   SELECT key FROM public.cities WHERE governorate_id = (SELECT id FROM public.governorates WHERE key='damascus') AND key='jaramana';
   -- Expected: 1 row.
   SELECT key FROM public.areas WHERE city_id = (SELECT id FROM public.cities WHERE key='jaramana' AND governorate_id=(SELECT id FROM public.governorates WHERE key='damascus'));
   -- Expected: 1 row 'jaramana-center'.
   ```
5. From the smoke-test surface, open the LocationPicker, pick Damascus → Jaramana. Confirm the new area appears in the area dropdown (plan headline acceptance criterion + SC-011).
6. Delete the test area + the test city via the admin pages. Confirm they disappear from both the admin list and the LocationPicker.

## Step 11 — Device walk: LocationPicker cascade (US6, FR-018..FR-022, SC-011/012)

1. Mount the LocationPicker on the smoke-test surface (or use the Phase 10 listing form when it ships).
2. Confirm the governorate dropdown lists all 14 governorates in editorial order (Damascus first).
3. Tap Aleppo → confirm city dropdown populates with Aleppo cities (4+ rows including Manbij / Afrin / Azaz per the seed inventory).
4. Tap one of the Aleppo cities that has zero seeded areas → confirm the "no areas yet — leave blank" affordance appears. Submit. Confirm `LocationPickerSelection {governorateId, cityId, areaId: null}` is emitted.
5. Reset. Pick Damascus → Damascus city → an area. Confirm `LocationPickerSelection` carries all three IDs.
6. Toggle locale ar↔en mid-selection. Confirm labels flip; selection is preserved.

## Step 12 — Cross-device propagation test (SC-007, SC-021)

1. On the admin device, edit Latakia's English name to "Latakia City". Save.
2. On a second device signed in as a regular user with the LocationPicker mounted (or on a second incognito session on the desktop emulator), foreground the app.
3. Open the LocationPicker fresh. Confirm "Latakia City" appears within 5 seconds of foregrounding (SC-007 acceptance: no app restart, no cache invalidation step needed — the read is fresh per R-20).
4. (Optional) Revoke `locations.manage` from the admin role via Phase 7's `RoleEditorPage`. Confirm — on next foreground resume of the admin device — the Locations tile disappears from the admin home (SC-021 / Phase 6 FR-015 invariant).
5. Re-grant `locations.manage`. Confirm the tile reappears on next foreground.

## Per-FR / Per-SC verification map

| Requirement | Step(s) |
|---|---|
| FR-001 (schema)            | Step 2 |
| FR-002 (FK + ON DELETE)    | Step 2 + Clarifications Q2 spot-check via `pg_constraint` |
| FR-003 (UNIQUE constraints)| Step 9.2 (duplicate key refused on Save) |
| FR-004 (14 governorates)   | Step 3 |
| FR-005 (30–40 cities)      | Step 3 |
| FR-006 (starter areas)     | Step 3 |
| FR-007 (audit triggers)    | Step 4 + Step 6 |
| FR-007a (immutability)     | Step 7 |
| FR-008 (write RLS gate)    | Step 6 |
| FR-009 (public SELECT)     | Step 5 |
| FR-010 (no new perms)      | Inspection of `public.permissions` — confirm 24 rows unchanged |
| FR-011 (cache refresh)     | Step 12.4–12.5 |
| FR-012 (Locations tile)    | Step 8 |
| FR-013 (route guard)       | Step 8.3 |
| FR-014 (admin pages)       | Steps 9 + 10 |
| FR-015 (system protection) | Step 9.4 + Step 7 |
| FR-016 (form validation)   | Step 9.1 (try empty Arabic name; confirm refused) |
| FR-017 (confirmation dialog) | Step 9.7 + Step 10.6 |
| FR-018..FR-022 (picker)    | Step 11 |
| FR-023 (ARB keys)          | Phase 3 lint guard at PR review + manual locale toggle in Step 11.6 |
| FR-024 (design tokens)     | PR review of `lib/features/locations/presentation/widgets/` files |
| FR-025 (audit per mutation)| Step 4 + Step 6 |
| SC-001/002/003/004         | Step 3 |
| SC-005                     | Step 5 |
| SC-006                     | Step 10 (timed; the headline 60-second flow) |
| SC-007                     | Step 12.1–12.3 |
| SC-008/009/010             | Step 8 + Step 6 |
| SC-011/012                 | Step 11 |
| SC-013                     | Step 4 |
| SC-014                     | Re-apply each Phase 8 migration via Supabase MCP `apply_migration` — confirm `audit_logs` row count for `*.created` is unchanged (idempotent ON CONFLICT DO NOTHING) |
| SC-015                     | Step 10.5 (deactivate a city, confirm picker hides it) |
| SC-016                     | Step 9.1 (form validation refuses empty Arabic / duplicate key) |
| SC-017                     | Step 9.4 + Step 7 |
| SC-018                     | Step 6 + inspection of `public.permissions` |
| SC-019                     | PR review: `grep -R "Color(0xFF" lib/features/locations/presentation/widgets/` returns 0 |
| SC-020                     | Phase 3 lint guard at PR review |
| SC-021                     | Step 12.4–12.5 |

## Close-out

- If all steps pass, mark `quickstart.md` as the Phase 8 acceptance signature; reviewer signs off in the PR description.
- Authored `DEFERRED.md` rows (if any) are reviewed at squash-merge time per project memory `project_deferred_work.md`.
- Optional `HANDOFF.md` is authored only if any work is in flight at close-out.
