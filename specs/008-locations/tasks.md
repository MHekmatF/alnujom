---

description: "Task list for Phase 8 — Locations Catalog (Governorates, Cities, Areas). Each task is self-contained with exact absolute file paths and contract pointers so a cheaper LLM can implement without context-switching. Tasks are dependency-ordered: Setup → Foundational backend → US7/US1 backend verification → Foundational Flutter data layer → US2/US3/US4/US5 → US6 LocationPicker → Polish."
---

# Tasks: Locations Catalog (Governorates, Cities, Areas)

**Input**: Design documents from `/specs/008-locations/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/*.md`, `quickstart.md` — all complete and locked at Session 2026-05-16.

**Tests**: **NONE.** Per durable session feedback (`feedback_no_new_tests.md`), Phase 8 introduces ZERO new automated tests. Verification is manual SQL via Supabase MCP `execute_sql` + manual UI walks on the reference Infinix Note 8 device. Existing Phase 1–7 tests remain unchanged.

**Organization**: Tasks are grouped by user story. Each story's checkpoint is a self-contained increment that can be demo'd without subsequent stories.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel with other [P]-marked tasks in the same phase (different files, no dependency on incomplete tasks).
- **[Story]**: User story label (US1..US7). Setup / Foundational / Polish tasks have NO story label.
- Every task includes the exact absolute file path and a pointer to the relevant contract / data-model section.

## Path Conventions

- Repository root: `H:\alnujom-project\`
- Supabase artifacts: `H:\alnujom-project\supabase\`
- Flutter sources: `H:\alnujom-project\lib\`
- ARB files: `H:\alnujom-project\lib\l10n\`

## Implementer briefing (read once before T001)

Before starting, read:

1. `H:\alnujom-project\specs\008-locations\spec.md` — entire file (especially the 5-bullet Clarifications section, the 7 user stories, and the 21 Success Criteria).
2. `H:\alnujom-project\specs\008-locations\plan.md` — entire file (especially the Project Structure tree which lists every file you will touch).
3. `H:\alnujom-project\specs\008-locations\data-model.md` — entire file (full CREATE TABLE bodies, trigger function bodies, RLS policy bodies, seed inventory, ARB key inventory, BLoC + entity shapes).
4. `H:\alnujom-project\specs\008-locations\quickstart.md` — Steps 1, 2, 3, 4 first; you'll re-read individual steps when verification tasks reference them.
5. Skim the 9 contract files in `H:\alnujom-project\specs\008-locations\contracts\` — these are the binding interface definitions.

When a task says "per `contracts/<X>.md` § Y" or "per `data-model.md` § Z", that section is your source of truth for the exact code/SQL — copy it verbatim and adjust only the table/column names called out in the task.

---

## Phase 1: Setup

**Purpose**: Confirm environment + warm the toolchain. No code authored yet.

- [x] T001 Verify current git state. Run `git status` and `git branch --show-current` from `H:\alnujom-project`. Expected: branch `008-locations`, working tree clean apart from the already-staged `specs/008-locations/*` files. If branch is different, STOP and ask. If tree has unrelated dirty files, commit or stash before proceeding.

- [x] T002 [P] Verify Phase 7 is shipped on the remote Supabase project. Run via Supabase MCP `execute_sql` four checks: (a) `SELECT count(*) FROM pg_proc WHERE proname IN ('mutate_role','assign_role_to_user','revoke_role_from_user')` returns `3`; (b) `SELECT count(*) FROM pg_policies WHERE policyname LIKE '%_phase7_%'` returns `7`; (c) `SELECT count(*) FROM pg_trigger WHERE tgname LIKE 'trg_%audit%' AND tgrelid IN ('public.roles'::regclass,'public.role_permissions'::regclass,'public.permissions'::regclass)` returns `8`; (d) `SELECT count(*) FROM public.permissions WHERE key='locations.manage'` returns `1`. If any check fails, STOP — Phase 8 cannot proceed without Phase 7 + the existing `locations.manage` permission row.

- [x] T003 [P] Verify `H:\alnujom-project\.env.json` exists and contains valid Supabase credentials (URL + anon key + service_role key per project memory `project_dart_defines.md`). If missing, STOP and ask the user to provide the file. Do NOT commit `.env.json` (it is in `.gitignore`).

- [x] T004 [P] Pre-warm the Flutter toolchain. From `H:\alnujom-project`, run in order: `flutter clean`, `flutter pub get`. (Do NOT run `build_runner` yet — it runs after the new `@injectable` annotations land in Phase 5; running it now would not regenerate the still-Phase-7 graph.)

- [x] T005 Capture pre-migration schema state to `H:\alnujom-project\specs\008-locations\baseline-pre-migration.txt` (mirror of Phase 7's `specs/007-super-admin-roles/baseline-pre-migration.txt`). Concatenate the following sections (use the section headers shown verbatim) into the file: (A) Supabase MCP `list_tables` output for the `public` schema; (B) Supabase MCP `list_migrations` output (full ordered list — the last entry MUST be `20260516120005_phase7_advisor_hardening`); (C) `SELECT count(*) FROM public.governorates` — expected: error `relation "public.governorates" does not exist` (this confirms Phase 8 tables are not yet present; record the error text in the file as the section body); (D) `SELECT key FROM public.permissions WHERE key='locations.manage'` — expected: one row; record the row; (E) **Analyzer baseline**: from `H:\alnujom-project`, run `flutter analyze --no-fatal-infos --no-fatal-warnings` and paste the full stdout/stderr verbatim under this section header (this is the baseline T106 will diff against — any warning that appears here is pre-existing and out of scope for Phase 8). This snapshot is the rollback reference if Phase 8 needs to be reverted AND the analyzer-comparison reference for T106.

**Checkpoint**: Environment confirmed, Phase 7 verified shipped, `.env.json` present, baseline snapshot captured.

---

## Phase 2: Foundational — Backend Migrations (Blocking Prerequisites)

**Purpose**: Apply the 5 Phase 8 migrations + 3 new policy files + 4 doc files. The 3 new tables, 9 audit triggers, 2 immutability triggers, 12 RLS policies, and the full seed inventory all land here. EVERY downstream user story depends on this phase.

**⚠️ CRITICAL**: No user story task may begin until Phase 2 is complete and verified.

### Migration 1 — governorates table

- [x] T006 Author migration 1 file at `H:\alnujom-project\supabase\migrations\20260517120001_create_governorates.sql`. (FR-001, FR-003, FR-004, FR-007, FR-007a, FR-008, FR-009.) Body MUST contain, in exactly this order: (1) leading SQL `-- COMMENT` block citing FR-001/003/004/007/007a/008/009 and noting "anonymous SELECT carve-out — see research.md R-04 and R-16"; (2) `CREATE TABLE IF NOT EXISTS public.governorates (...)` from `data-model.md` § 1.1 (full body, all 9 columns, all 3 CHECK constraints, all COMMENT ON statements); (3) `ALTER TABLE public.governorates ENABLE ROW LEVEL SECURITY;`; (4) `set_updated_at` trigger attach from `data-model.md` § 3.1; (5) `enforce_governorate_system_immutability` trigger function + trigger from `data-model.md` § 3.2 (use the full function body shown); (6) the 3 audit triggers from `data-model.md` § 3.4 (governorates section); (7) the 4 RLS policies from `data-model.md` § 4 (substitute table name `governorates` and the policy names from `contracts\phase8-rls-policies.md`); (8) seed INSERT of 14 governorates from `data-model.md` § 5.1 using `ON CONFLICT (key) DO NOTHING`. The order matters per R-08 (triggers BEFORE seed).

- [x] T007 Apply migration 1 via Supabase MCP `apply_migration` with name `20260517120001_create_governorates` and body from T006. Then verify via Supabase MCP `execute_sql`: (a) `SELECT count(*) FROM public.governorates` returns `14`; (b) `SELECT count(*) FROM public.governorates WHERE is_system` returns `14`; (c) `SELECT count(*) FROM pg_trigger WHERE tgrelid='public.governorates'::regclass AND NOT tgisinternal` returns `5` (3 audit + set_updated_at + enforce_immutability); (d) `SELECT count(*) FROM pg_policies WHERE tablename='governorates'` returns `4`; (e) `SELECT count(*) FROM public.audit_logs WHERE action='governorate.created' AND actor_user_id IS NULL` returns `14` (the seed produced audit rows per R-08).

- [x] T008 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\governorates_phase8.sql`. Body MUST be a verbatim copy of the 4 `DROP POLICY IF EXISTS ... CREATE POLICY ...` blocks from migration 1 step (7). The 4 policy names are: `governorates_select_public` (SELECT, anon+authenticated, USING true), `governorates_insert_locations_manage` (INSERT, authenticated, WITH CHECK current_user_has_permission('locations.manage')), `governorates_update_locations_manage` (UPDATE, authenticated, USING + WITH CHECK same predicate), `governorates_delete_locations_manage` (DELETE, authenticated, USING same predicate). Add a leading comment: `-- Mirror of the inline RLS policies in supabase/migrations/20260517120001_create_governorates.sql. R-02 dual-storage invariant.`

### Migration 2 — cities table

- [x] T009 Author migration 2 file at `H:\alnujom-project\supabase\migrations\20260517120002_create_cities.sql`. (FR-001, FR-002, FR-003, FR-005, FR-007, FR-007a, FR-008, FR-009.) Body order mirrors T006 exactly with substitutions: (1) leading `-- COMMENT` citing FR-001/002/003/005/007/007a/008/009; (2) `CREATE TABLE IF NOT EXISTS public.cities` from `data-model.md` § 1.2 — note the `governorate_id UUID NOT NULL REFERENCES public.governorates(id) ON DELETE CASCADE` FK per Clarifications Q2; (3) RLS enable; (4) `set_updated_at`; (5) `enforce_city_system_immutability` trigger function + trigger from `data-model.md` § 3.3 (symmetric to § 3.2 — use the same body template, substitute `city` for `governorate`); (6) 3 audit triggers (`trg_cities_audit_created/updated/deleted` calling `log_audit('city.created'/.updated/.deleted', '*', 'id')`); (7) 4 RLS policies `cities_select_public` / `cities_insert_locations_manage` / `cities_update_locations_manage` / `cities_delete_locations_manage` per `contracts\phase8-rls-policies.md`; (8) seed INSERT of ~32 cities from `data-model.md` § 5.2 using `ON CONFLICT (governorate_id, key) DO NOTHING`. The seed INSERT uses subquery `(SELECT id FROM public.governorates WHERE key = '<gov-key>')` to resolve each city's `governorate_id`.

- [x] T010 Apply migration 2 via Supabase MCP `apply_migration` name `20260517120002_create_cities` body from T009. Then verify: (a) `SELECT count(*) FROM public.cities` returns between 30 and 40 (the 30–40 target band from Clarifications Q4); (b) `SELECT count(*) FROM public.cities WHERE is_system` equals the same value (every seeded city is is_system=true); (c) `SELECT key FROM public.cities WHERE key IN ('damascus','aleppo','homs','latakia','tartus','hama')` returns 6 rows (the named major cities); (d) `SELECT count(*) FROM pg_trigger WHERE tgrelid='public.cities'::regclass AND NOT tgisinternal` returns `5`; (e) `SELECT count(*) FROM pg_policies WHERE tablename='cities'` returns `4`; (f) `SELECT count(*) FROM public.audit_logs WHERE action='city.created' AND actor_user_id IS NULL` equals the city count from (a); (g) verify CASCADE: `SELECT confdeltype FROM pg_constraint WHERE conrelid='public.cities'::regclass AND contype='f'` returns `c` (CASCADE).

- [x] T011 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\cities_phase8.sql`. Body MUST be a verbatim copy of the 4 policy blocks from migration 2 step (7). The 4 policy names are: `cities_select_public`, `cities_insert_locations_manage`, `cities_update_locations_manage`, `cities_delete_locations_manage` (same SELECT/INSERT/UPDATE/DELETE + role + predicate shape as T008's `governorates_*` set, substituting the table name). Add a leading comment: `-- Mirror of the inline RLS policies in supabase/migrations/20260517120002_create_cities.sql. R-02 dual-storage invariant.`

### Migration 3 — areas table

- [x] T012 Author migration 3 file at `H:\alnujom-project\supabase\migrations\20260517120003_create_areas.sql`. (FR-001, FR-002, FR-003, FR-006, FR-007, FR-008, FR-009.) Body order mirrors T006/T009 EXCEPT NO `is_system` column AND NO immutability trigger (areas have no protected seed per Clarifications Q3). The body: (1) leading `-- COMMENT` citing FR-001/002/003/006/007/008/009 and noting "no immutability trigger — areas have no protected seed"; (2) `CREATE TABLE IF NOT EXISTS public.areas` from `data-model.md` § 1.3 (note: no `is_system` column; `city_id` FK with `ON DELETE CASCADE`); (3) RLS enable; (4) `set_updated_at`; (5) **SKIP** — no immutability trigger; (6) 3 audit triggers (`trg_areas_audit_created/updated/deleted` calling `log_audit('area.created'/.updated/.deleted', '*', 'id')`); (7) 4 RLS policies for `areas`; (8) seed INSERT of starter areas from `data-model.md` § 5.3 (~6–10 rows) using `ON CONFLICT (city_id, key) DO NOTHING`. The seed uses nested subqueries `(SELECT id FROM public.cities WHERE key='<city-key>' AND governorate_id=(SELECT id FROM public.governorates WHERE key='<gov-key>'))` to resolve each area's `city_id`.

- [x] T013 Apply migration 3 via Supabase MCP `apply_migration` name `20260517120003_create_areas` body from T012. Then verify: (a) `SELECT count(*) FROM public.areas` returns the exact count of areas in the migration's `VALUES` list (planned: 9 rows from `data-model.md` § 5.3 — `old-city-damascus`, `mezzeh`, `mashrouh-dummar`, `aleppo-old-city`, `sulaymaniyah`, `homs-old-city`, `latakia-corniche`, `tartus-corniche`, `hama-norias`; record the actual count in `baseline-pre-migration.txt`'s post-Phase-8 addendum); (b) `SELECT count(*) FROM pg_attribute WHERE attrelid='public.areas'::regclass AND attname='is_system'` returns `0` (no is_system column — defense against accidental inclusion); (c) `SELECT count(*) FROM pg_trigger WHERE tgrelid='public.areas'::regclass AND NOT tgisinternal` returns `4` (3 audit + set_updated_at; NO immutability trigger); (d) `SELECT count(*) FROM pg_policies WHERE tablename='areas'` returns `4`; (e) verify CASCADE on `city_id` FK (same query shape as T010(g)); (f) `SELECT count(*) FROM public.audit_logs WHERE action='area.created' AND actor_user_id IS NULL` returns the same count as (a).

- [x] T014 [P] Author parallel policy file `H:\alnujom-project\supabase\policies\areas_phase8.sql`. Body MUST be a verbatim copy of the 4 policy blocks from migration 3 step (7). The 4 policy names are: `areas_select_public`, `areas_insert_locations_manage`, `areas_update_locations_manage`, `areas_delete_locations_manage`. Add a leading comment: `-- Mirror of the inline RLS policies in supabase/migrations/20260517120003_create_areas.sql. R-02 dual-storage invariant.`

### Migration 4 — performance indexes

- [x] T015 Author migration 4 file at `H:\alnujom-project\supabase\migrations\20260517120004_create_locations_indexes.sql`. (Performance Goals — supports SC-006/SC-007 query latency.) Body: leading `-- COMMENT` citing Performance Goals from `plan.md`; then 8 `CREATE INDEX IF NOT EXISTS` statements verbatim from `data-model.md` § 2 (idx_governorates_position_key, idx_governorates_is_active, idx_cities_governorate_id, idx_cities_is_active, idx_cities_position_key, idx_areas_city_id, idx_areas_is_active, idx_areas_position_key).

- [x] T016 Apply migration 4 via Supabase MCP `apply_migration` name `20260517120004_create_locations_indexes` body from T015. Verify: (a) `SELECT count(*) FROM pg_indexes WHERE schemaname='public' AND tablename IN ('governorates','cities','areas') AND indexname LIKE 'idx_%'` returns `8`; (b) `SELECT indexdef FROM pg_indexes WHERE indexname='idx_governorates_position_key'` returns a string containing `(position NULLS LAST, key)` (confirms the composite index parsed `NULLS LAST` as a sort modifier, not as a function call); (c) `SELECT indexdef FROM pg_indexes WHERE indexname='idx_cities_position_key'` returns a string containing `(governorate_id, position NULLS LAST, key)`; (d) `SELECT indexdef FROM pg_indexes WHERE indexname='idx_areas_position_key'` returns a string containing `(city_id, position NULLS LAST, key)`.

### Migration 5 — advisor hardening

- [x] T017 Author migration 5 file at `H:\alnujom-project\supabase\migrations\20260517120005_phase8_advisor_hardening.sql`. (FR-009, R-04, R-16.) Body MUST contain exactly these statements, in this order, and NOTHING ELSE: (1) leading `-- COMMENT` block: `-- Phase 8: Advisor hardening for the locations catalog. -- Source: specs/008-locations/research.md R-04 (anon SELECT carve-out) + R-16 (documented in migration comments). -- Pattern: codify the anon GRANT explicitly + REVOKE the write surfaces from anon as defense-in-depth on top of the RLS policies.`; (2) three `GRANT SELECT ON public.<table> TO anon, authenticated;` statements (one each for `governorates`, `cities`, `areas`); (3) three `REVOKE INSERT, UPDATE, DELETE ON public.<table> FROM anon;` statements (one each for the three tables). **Do NOT add `ALTER TABLE ... FORCE ROW LEVEL SECURITY` and do NOT add `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`** — RLS is already enabled in the table-creation migrations (T006/T009/T012 step 3). Phase 7's `20260516120005_phase7_advisor_hardening.sql` confirms this pattern (it contains only REVOKE/GRANT on functions, no ALTER TABLE).

- [x] T018 Apply migration 5 via Supabase MCP `apply_migration` name `20260517120005_phase8_advisor_hardening` body from T017. Then run Supabase MCP `get_advisors` type=`security` and confirm there are NO new advisor entries beyond what Phase 7 already accepts. Specifically, the new tables should NOT introduce any of: `function_search_path_mutable`, `rls_disabled`, `policy_exists_rls_disabled`. If any new lint appears, STOP and investigate — likely indicates the FORCE/ENABLE choice in T017 was wrong OR a policy was authored with `USING (current_user_has_permission(...))` instead of `WITH CHECK (...)`. Cross-check against `contracts/phase8-rls-policies.md` for the exact USING/WITH CHECK shape.

### Doc files

- [x] T019 [P] Author `H:\alnujom-project\supabase\docs\governorates.md`. Body: a brief Markdown reference describing the table (column shape per `data-model.md` § 1.1, RLS posture per § 4, immutability trigger per § 3.2, audit-trigger action keys `governorate.created/.updated/.deleted`, seed inventory size of 14 with `is_system=true`). Cite Phase 8 spec FR-001/004/007/007a/008/009. Mirror the format used in existing files like `supabase/docs/roles.md` and `supabase/docs/permissions.md`.

- [x] T020 [P] Author `H:\alnujom-project\supabase\docs\cities.md`. Same shape as T019, substituting cities-specific details from `data-model.md` § 1.2 and § 5.2. Note the `governorate_id` FK with ON DELETE CASCADE.

- [x] T021 [P] Author `H:\alnujom-project\supabase\docs\areas.md`. Same shape as T019/T020, substituting areas-specific details from § 1.3 and § 5.3. Explicitly note: no `is_system` column; no immutability trigger; every area row is fully editable/deletable.

- [x] T022 Update `H:\alnujom-project\supabase\docs\audit_logs.md`. Append the 9 new action keys to the enumeration: `governorate.created`, `governorate.updated`, `governorate.deleted`, `city.created`, `city.updated`, `city.deleted`, `area.created`, `area.updated`, `area.deleted`. Match the existing format (Phase 5/6/7 entries are already there). Cite Phase 8 FR-007.

**Checkpoint**: All 5 migrations applied; 3 new tables exist with RLS + 14 triggers + 12 policies; seed inventory in place (14 governorates + 30–40 cities + starter areas); 3 new doc files + 1 updated doc file checked in. The backend half of Phase 8 is shipped.

---

## Phase 3: User Story 7 — Audit Trail Coverage (Priority: P2) — backend verification

**Goal**: Confirm every `governorates` / `cities` / `areas` mutation through any path (in-app or direct SQL) emits exactly one `audit_logs` row, and that the trigger-before-seed ordering (Clarifications Q5) produced the expected ~50–64 initial-seed audit rows.

**Independent Test**: Run synthetic mutations via Supabase MCP `execute_sql` and confirm the audit rows match the contract.

- [x] T023 [US7] Verify initial-seed audit-row coverage (FR-007, SC-013, R-08). Run via Supabase MCP `execute_sql`: `SELECT action, count(*) FROM public.audit_logs WHERE action IN ('governorate.created','city.created','area.created') AND actor_user_id IS NULL GROUP BY action ORDER BY action`. Expected: `area.created` count matches the seeded areas inventory from T012; `city.created` matches the cities count from T010; `governorate.created` equals 14. Cross-check against `quickstart.md` § Step 4.

- [x] T024 [US7] Verify live mutation produces audit rows (FR-025, SC-013). Run via Supabase MCP `execute_sql` (which runs as `postgres`): `INSERT INTO public.governorates (key, display_name) VALUES ('audit-test-gov', '{"ar":"اختبار","en":"AuditTest"}'::jsonb)`; immediately run `SELECT action, actor_user_id, target_id FROM public.audit_logs WHERE action='governorate.created' ORDER BY occurred_at DESC LIMIT 1` — confirm exactly one new row with `actor_user_id=NULL` (postgres carries no auth.uid). Then `UPDATE public.governorates SET display_name = display_name || '{"en":"Audit Test 2"}'::jsonb WHERE key='audit-test-gov'`; confirm a new `governorate.updated` row appears. Then `DELETE FROM public.governorates WHERE key='audit-test-gov'`; confirm a new `governorate.deleted` row appears.

- [x] T025 [US7] Verify immutability triggers refuse protected operations (FR-007a, SC-017, Clarifications Q3, R-07). Run via Supabase MCP `execute_sql`: (a) `DELETE FROM public.governorates WHERE key='damascus'` — expected: `ERROR 42501 governorate_system_immutable: cannot delete a system governorate (key=damascus)`; (b) `UPDATE public.governorates SET key='dimashq' WHERE key='damascus'` — expected: `ERROR 42501 governorate_system_immutable: cannot rename a system governorate's key`; (c) `UPDATE public.governorates SET display_name = display_name || '{"fr":"Damas"}'::jsonb WHERE key='damascus'` — expected: SUCCESS, 1 row updated (display_name UPDATE is allowed on is_system=true rows); (d) restore: `UPDATE public.governorates SET display_name = jsonb_set(display_name, '{ar}', '"دمشق"') WHERE key='damascus'`; (e) symmetric checks on cities: `DELETE FROM public.cities WHERE key='damascus' AND governorate_id=(SELECT id FROM public.governorates WHERE key='damascus')` — expected: `ERROR 42501 city_system_immutable: ...`; `UPDATE public.cities SET key='dimashq' WHERE key='damascus' AND governorate_id=...` — expected: same error; (f) confirm areas have NO immutability — pick any seeded area and verify `DELETE FROM public.areas WHERE id=<some-area-id>` succeeds; then re-INSERT it to restore the seed.

- [x] T026 [US7] Verify Phase 4 `log_audit()` function body unchanged (R-13). Run via Supabase MCP `execute_sql`: `SELECT pg_get_functiondef('public.log_audit(text, text, text)'::regprocedure)`. Confirm the returned body is byte-identical to what `T005`'s baseline captured (Phase 4 reusability invariant preserved a fifth time across Phases 4/5/6/7/8).

- [x] T027 [US7] Verify `current_user_has_permission(text)` body unchanged (R-14). Run via Supabase MCP `execute_sql`: `SELECT pg_get_functiondef('public.current_user_has_permission(text)'::regprocedure)`. Confirm the returned body matches the baseline (Phase 6 helper unchanged a fourth time).

- [x] T028 [US7] Verify migration idempotency (SC-014). Re-apply each of the five Phase 8 migrations a second time via Supabase MCP `apply_migration` (same name, same body). Each apply MUST succeed without error. Then verify no duplicates: (a) `SELECT tgname, count(*) FROM pg_trigger WHERE tgname LIKE 'trg_governorates_%' OR tgname LIKE 'trg_cities_%' OR tgname LIKE 'trg_areas_%' GROUP BY tgname HAVING count(*) > 1` returns 0 rows; (b) `SELECT policyname, count(*) FROM pg_policies WHERE policyname LIKE '%locations_manage%' OR policyname LIKE '%select_public%' GROUP BY policyname HAVING count(*) > 1` returns 0 rows; (c) `SELECT count(*) FROM public.governorates` STILL returns `14` (no duplicates inserted because `ON CONFLICT (key) DO NOTHING`); (d) `SELECT count(*) FROM public.audit_logs WHERE action='governorate.created' AND actor_user_id IS NULL` STILL returns `14` (no extra audit rows from the re-apply because the seed INSERTs were no-ops). Note: `supabase_migrations.schema_migrations` MAY show duplicate tracker rows per project memory `project_supabase_mcp_apply_migration.md` — that is acceptable.

**Checkpoint**: US7 verified independently. The audit trail covers every Phase 8 mutation surface; immutability triggers refuse protected operations; Phase 4 `log_audit` and Phase 6 `current_user_has_permission` are unchanged; migrations are confirmed idempotent.

---

## Phase 4: User Story 1 — Public clients see seeded catalog (Priority: P1) — backend verification

**Goal**: Confirm the public-read RLS policy admits both anonymous and authenticated clients across all three tables (R-04). The Flutter consumer surface lands later (US6); this phase verifies the backend is ready.

**Independent Test**: Issue SELECT queries with both anon and authenticated JWTs against all three tables and confirm full visibility of the seed.

- [x] T029 [US1] Verify anonymous SELECT admits all rows (FR-009, SC-001, SC-002, SC-003, SC-004, SC-005, R-04). Run via Supabase MCP `execute_sql`, simulating anon by setting `SET LOCAL ROLE anon;` (then reset with `RESET ROLE;` at the end of the block): (a) `SELECT count(*) FROM public.governorates` returns `14`; (b) `SELECT count(*) FROM public.cities` returns 30–40 (the seed count); (c) `SELECT count(*) FROM public.areas` returns ≥1; (d) `SELECT count(*) FROM public.governorates WHERE display_name->>'ar' IS NOT NULL AND display_name->>'en' IS NOT NULL` equals 14 (bilingual coverage per SC-004); (e) attempt `INSERT INTO public.governorates (key, display_name) VALUES ('hack', '{"ar":"اختراق"}')` — expected: 0 rows affected OR explicit RLS denial error.

- [x] T030 [US1] Verify authenticated SELECT admits all rows for any user (FR-009, no permission required). First look up the test UUID: run `SELECT id FROM auth.users WHERE email='<a-test-user-email>@<...>' LIMIT 1` and substitute the returned UUID for `<user-uuid>` below. (Replace the angle-bracket placeholder; do NOT execute the SQL literally with `<...>` in it.) Pick any Phase 5 regular `user`-only test account UUID. Run via Supabase MCP `execute_sql`: `SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub TO '<user-uuid>';` then `SELECT count(*) FROM public.governorates`, `SELECT count(*) FROM public.cities`, `SELECT count(*) FROM public.areas`. Each MUST return the same count as T029. Reset role at end.

- [x] T031 [US1] Verify anonymous client CANNOT WRITE. Continue under `SET LOCAL ROLE anon;`. Attempt: (a) `INSERT INTO public.cities (governorate_id, key, display_name) VALUES ((SELECT id FROM public.governorates LIMIT 1), 'hack', '{"ar":"x"}')` — expected: 0 rows or RLS deny; (b) `UPDATE public.governorates SET is_active=false WHERE key='damascus'` — expected: 0 rows or RLS deny; (c) `DELETE FROM public.areas WHERE TRUE` — expected: 0 rows or RLS deny.

**Checkpoint**: US1 backend-side verified. Anonymous and authenticated clients can read the full catalog; no client without `locations.manage` can write.

---

## Phase 5: Foundational — Flutter Data + Domain Layer

**Purpose**: Author the entire `lib/features/locations/data/` and `lib/features/locations/domain/` trees. These are shared by every subsequent UI phase (US2 through US6). The presentation layer is built per-story in Phase 6 onwards.

**⚠️ CRITICAL**: No US2/US3/US4/US5/US6 task may begin until Phase 5 is complete (the BLoCs and pages in later phases depend on the use cases, entities, and repository defined here).

### Domain entities

- [x] T032 [P] Create `H:\alnujom-project\lib\features\locations\domain\entities\governorate.dart`. (FR-001, FR-021.) Body: pure Dart `class Governorate extends Equatable { ... }` per `data-model.md` § 6.1. Fields: `id`, `key`, `displayName` (`Map<String, String>`), `description` (`Map<String, String>?`), `position` (`int?`), `isActive`, `isSystem`, `createdAt`, `updatedAt`. Method: `String localizedName(Locale locale)` implementing the (active → other → key) fallback chain from R-18. No `package:supabase_flutter` import. Constitution IX compliance.

- [x] T033 [P] Create `H:\alnujom-project\lib\features\locations\domain\entities\city.dart`. Same shape as T032 plus `final String governorateId;` field (UUID string). Implements `localizedName(Locale)` identically. No Supabase imports.

- [x] T034 [P] Create `H:\alnujom-project\lib\features\locations\domain\entities\area.dart`. Same shape as T032 BUT omit `isSystem` (areas have no protected seed) AND replace `governorateId` with `final String cityId;`. Implements `localizedName(Locale)`. No Supabase imports.

- [x] T035 [P] Create `H:\alnujom-project\lib\features\locations\domain\entities\governorate_with_city_count.dart`. Pure Dart class wrapping a `Governorate` plus an `int cityCount`; extends Equatable. Used by `LocationsListPage` to display the rolled-up count.

- [x] T036 [P] Create `H:\alnujom-project\lib\features\locations\domain\entities\city_with_area_count.dart`. Symmetric to T035: wraps a `City` plus `int areaCount`. Used by `GovernorateDetailPage`.

- [x] T037 [P] Create `H:\alnujom-project\lib\features\locations\domain\entities\location_picker_selection.dart`. (FR-022.) Per `data-model.md` § 6.1: `class LocationPickerSelection extends Equatable { final String governorateId; final String cityId; final String? areaId; const LocationPickerSelection({required this.governorateId, required this.cityId, this.areaId}); @override List<Object?> get props => [governorateId, cityId, areaId]; }`. The `areaId` is nullable per FR-019.

- [x] T038 [P] Create `H:\alnujom-project\lib\features\locations\domain\failures.dart`. Per the Phase 7 `super_admin/domain/failures.dart` precedent + `data-model.md` § 10. Define `sealed class LocationsFailure { ... }` with subclasses `NotAuthorized`, `KeyAlreadyUsed`, `SystemRowProtected`, `ForeignKeyViolation`, `Network`, `Unknown`. Each carries an optional `message: String` field for debug logging.

### Domain repository (abstract)

- [x] T039 Create `H:\alnujom-project\lib\features\locations\domain\repositories\locations_repository.dart`. (FR-001, FR-008, FR-017.) Body: abstract class with the full method list from `data-model.md` § 6.2 — including the three count helpers (`countCitiesInGovernorate`, `countAreasInCity`, `countAreasInGovernorate`). Methods (each returns `Future<Either<LocationsFailure, T>>` per Phase 7 precedent, OR uses `Future<T>` that throws on failure — match whichever pattern `lib/features/super_admin/domain/repositories/role_catalog_repository.dart` uses; open that file first to determine the convention before authoring). No Supabase imports.

### Domain use cases

- [x] T040 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\list_governorates.dart`. Single-method use case. Import: `import 'package:injectable/injectable.dart';` and the entity / repository imports. Body: `@injectable class ListGovernorates { final LocationsRepository repository; const ListGovernorates(this.repository); Future<List<GovernorateWithCityCount>> call({required bool includeInactive}) => repository.listGovernorates(includeInactive: includeInactive); }`. The `@injectable` annotation (NO `as:` argument — that variant is only for repository impls binding to abstract types) registers the class as a factory in `injection.config.dart` via the build_runner pass in T062. **All subsequent use case files (T041–T053, T079, T087) use this exact `@injectable` + constructor-injection pattern; the only differences are the class name, return type, and method signature.**

- [x] T041 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\load_governorate_detail.dart`. Same shape: `call(String id)`.

- [x] T042 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\list_cities_for_governorate.dart`. `call({required String governorateId, required bool includeInactive})`.

- [x] T043 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\load_city_detail.dart`. `call(String id)`.

- [x] T044 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\list_areas_for_city.dart`. `call({required String cityId, required bool includeInactive})`.

- [x] T045 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\create_governorate.dart`. `call({required String key, required Map<String, String> displayName, Map<String, String>? description, int? position, bool isActive = true})` delegating to `repository.createGovernorate(...)`.

- [x] T046 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\update_governorate.dart`. `call(String id, {Map<String, String>? displayName, Map<String, String>? description, int? position, bool? isActive, String? key})`. Note: the `key` parameter is rejected server-side by the immutability trigger if the row is `is_system=true`; the UI hides the field in that case (FR-015).

- [x] T047 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\delete_governorate.dart`. `call(String id)`. Server-side immutability trigger refuses if `is_system=true`.

- [x] T048 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\create_city.dart`. `call({required String governorateId, required String key, required Map<String, String> displayName, Map<String, String>? description, int? position, bool isActive = true})`.

- [x] T049 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\update_city.dart`. Same shape as `update_governorate.dart` minus `governorateId` (the city's parent cannot move; that's a re-create).

- [x] T050 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\delete_city.dart`. `call(String id)`. Cascades to areas per CASCADE FK.

- [x] T051 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\create_area.dart`. `call({required String cityId, required String key, required Map<String, String> displayName, Map<String, String>? description, int? position, bool isActive = true})`.

- [x] T052 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\update_area.dart`. Same shape as `update_city.dart` minus `cityId`.

- [x] T053 [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\delete_area.dart`. `call(String id)`. No immutability check needed — areas are fully deletable.

### Data layer DTOs

- [x] T054 [P] Create `H:\alnujom-project\lib\features\locations\data\dtos\governorate_dto.dart`. Body: `class GovernorateDto { ... }` with `fromJson(Map<String, dynamic>)` and `toEntity() => Governorate(...)` methods. Maps the Postgres column shape (lowercase snake_case keys: `id`, `key`, `display_name`, `description`, `position`, `is_active`, `is_system`, `created_at`, `updated_at`) to the domain entity. The `display_name` JSONB arrives as a `Map<String, dynamic>` — cast to `Map<String, String>` defensively (`.map((k, v) => MapEntry(k, v?.toString() ?? ''))`). May import `package:supabase_flutter` if the DTO uses `PostgrestMap` typing — otherwise pure Dart.

- [x] T055 [P] Create `H:\alnujom-project\lib\features\locations\data\dtos\city_dto.dart`. Same shape as T054 plus `governorate_id` field. `toEntity() => City(governorateId: ..., ...)`.

- [x] T056 [P] Create `H:\alnujom-project\lib\features\locations\data\dtos\area_dto.dart`. Same shape minus `is_system`, plus `city_id`.

- [x] T057 [P] Create `H:\alnujom-project\lib\features\locations\data\dtos\governorate_with_city_count_dto.dart`. Wraps `GovernorateDto` plus an `int cityCount` field. The data source's `listGovernorates` query returns rows with a `city_count` extra column (rolled-up); this DTO parses it.

- [x] T058 [P] Create `H:\alnujom-project\lib\features\locations\data\dtos\city_with_area_count_dto.dart`. Symmetric.

### Data layer datasource + repository impl

- [x] T059 Create `H:\alnujom-project\lib\features\locations\data\datasources\supabase_locations_datasource.dart`. (FR-001, FR-008, FR-009.) Body: `@injectable class SupabaseLocationsDatasource { ... }` with one method per read/write operation in the abstract repository (T039). Each method uses the Supabase client (`Supabase.instance.client.from('governorates').select(...)`, etc.). The COMPLETE method list — every one MUST be implemented in this file, with the SQL/PostgREST pattern shown: (1) `listGovernorates({required bool includeInactive})` → `.from('governorates').select('*, city_count:cities(count)')` + optional `.eq('is_active', true)` + `.order('position', ascending: true, nullsFirst: false).order('key')`; (2) `loadGovernorate(id)` → `.from('governorates').select().eq('id', id).single()`; (3) `listCitiesForGovernorate({governorateId, includeInactive})` → `.from('cities').select('*, area_count:areas(count)').eq('governorate_id', governorateId)` + optional active filter + order; (4) `loadCity(id)` → symmetric; (5) `listAreasForCity({cityId, includeInactive})` → `.from('areas').select().eq('city_id', cityId)` + optional active filter + order; (6) `createGovernorate/createCity/createArea` → `.from('<table>').insert({...}).select().single()`; (7) `updateGovernorate/updateCity/updateArea` → `.from('<table>').update({...}).eq('id', id).select().single()`; (8) `deleteGovernorate/deleteCity/deleteArea` → `.from('<table>').delete().eq('id', id)`; (9) **count helpers** (consumed by T079/T080/T086/T087): `countCitiesInGovernorate(govId)` → `.from('cities').select('id', const FetchOptions(count: CountOption.exact, head: true)).eq('governorate_id', govId)` returning `response.count ?? 0`; (10) `countAreasInGovernorate(govId)` — issue raw RPC OR a two-step query: first fetch city ids `.from('cities').select('id').eq('governorate_id', govId)` then `.from('areas').select('id', const FetchOptions(count: CountOption.exact, head: true)).inFilter('city_id', cityIds)`; (11) `countAreasInCity(cityId)` → `.from('areas').select('id', const FetchOptions(count: CountOption.exact, head: true)).eq('city_id', cityId)`. ON ERROR: catch `PostgrestException` and map to `LocationsFailure` per `data-model.md` § 10 (SQLSTATE `42501` → `NotAuthorized` if message contains 'permission' else `SystemRowProtected` if message contains `_system_immutable`; `23505` → `KeyAlreadyUsed`; `23503` → `ForeignKeyViolation`). Reference Phase 7's `supabase_role_catalog_datasource.dart` for the exception-handling shape.

- [x] T060 Create `H:\alnujom-project\lib\features\locations\data\repositories\locations_repository_impl.dart`. Body: `@LazySingleton(as: LocationsRepository) class LocationsRepositoryImpl implements LocationsRepository { final SupabaseLocationsDatasource datasource; ... }`. Each method calls the corresponding datasource method, wraps DTO results in entities, returns the domain type. The ONLY file in the new feature folder that imports both `data/dtos/*` and `domain/repositories/locations_repository.dart` (Constitution IX boundary). Reference Phase 7's `role_catalog_repository_impl.dart`.

### Permission key + DI

- [x] T061 Verify `H:\alnujom-project\lib\core\security\permission_keys.dart` already contains `static const String locationsManage = 'locations.manage';` (introduced in Phase 6). (FR-010, SC-018.) Open the file and confirm. Do NOT add a new constant — FR-010 prohibits new permission keys. If the constant is missing for any reason, STOP and check Phase 6's data-model — the Phase 6 §9.1 mapping should have introduced it. Then run via Supabase MCP `execute_sql`: `SELECT count(*) FROM public.permissions` — record the count. If it changed from the Phase 7 baseline (24 rows per the Phase 7 spec), Phase 8 has inadvertently introduced a permission key — STOP and revert the offending change. Phase 8 ships with the exact same 24 rows in `public.permissions` (SC-018: `locations.manage` is the only key gating Phase 8 write access).

- [x] T062 Run codegen to regenerate the DI graph. From `H:\alnujom-project`, run `flutter pub run build_runner build --delete-conflicting-outputs`. Verify `H:\alnujom-project\lib\core\di\injection.config.dart` now contains entries for `SupabaseLocationsDatasource`, `LocationsRepositoryImpl`, and the 14 use cases (one for each from T040–T053). If codegen errors, the most common cause is a missing import or a missing `@injectable` annotation on one of the new files — fix and re-run.

### ARB keys

- [x] T063 Append the ~25 new ARB keys to `H:\alnujom-project\lib\l10n\app_ar.arb` from `data-model.md` § 8 table. (FR-023, Constitution V.) Each key gets the Arabic value from the table. Maintain the existing JSON shape; insert the new entries near the end (after the Phase 7 entries). Also add the missing keys discovered in T074/T085: `subtitleCityCount` (Arabic plural-aware: "{cityCount} مدينة") and `subtitleAreaCount` ("{areaCount} منطقة"). If the project's ARB pipeline supports ICU `{count, plural, ...}` syntax, use it; otherwise use the simple `{cityCount}` placeholder form. Run `flutter gen-l10n` (or `flutter pub run build_runner build --delete-conflicting-outputs` if the project uses build_runner for l10n) to regenerate the typed accessor.

- [x] T064 Append the same ~25 ARB keys to `H:\alnujom-project\lib\l10n\app_en.arb` with the English values from `data-model.md` § 8 table. (FR-023, Constitution V.) Also add `subtitleCityCount` ("{cityCount} cities") and `subtitleAreaCount` ("{areaCount} areas"). Both files MUST be updated in the same commit per Phase 3's localization gate. Re-run gen-l10n.

**Checkpoint**: Flutter data + domain layer scaffolded. All 14 use cases callable; the repository impl wires to the Supabase client; ARB keys regenerated; DI graph rebuilt. No UI exists yet.

---

## Phase 6: User Story 2 — Admin entry tile + Route Guards (Priority: P1)

**Goal**: Wire up the `/admin/locations/*` routes and add the "Locations" tile to `AdminHomePage`, gated by `PermissionChecker.has('locations.manage')`. Pages render as empty skeletons; their content lands in US3/US4/US5.

**Independent Test**: Sign in as the moderator (no `locations.manage`) and confirm the tile is hidden AND deep-link refused. Sign in as admin (has `locations.manage`) and confirm the tile appears AND deep-link opens the placeholder list page.

- [x] T065 [US2] Create skeleton `H:\alnujom-project\lib\features\locations\presentation\pages\locations_list_page.dart`. (FR-014.) For now, render a `Scaffold` with `AppBar(title: Text(AppLocalizations.of(context).locationsListPageTitle))` and a body containing `Center(child: Text('US3 lands here'))`. Do NOT wrap in `BlocProvider` here — US3 (T080) adds the provider when it fills in the page. Phase 2 design tokens for the AppBar.

- [x] T066 [US2] Create skeleton `H:\alnujom-project\lib\features\locations\presentation\pages\governorate_detail_page.dart`. (FR-014.) Same placeholder pattern as T065. AppBar title uses `governorateDetailPageTitle` ARB key. Reads `:governorateId` from `GoRouterState.of(context).pathParameters['governorateId']` and shows it in the placeholder body (`Center(child: Text('US4 lands here — governorateId=$governorateId'))`) for visual confirmation that routing works.

- [x] T067 [US2] Create skeleton `H:\alnujom-project\lib\features\locations\presentation\pages\city_detail_page.dart`. (FR-014.) Same placeholder pattern as T065. AppBar title uses `cityDetailPageTitle` ARB key. Reads both `:governorateId` and `:cityId` from `GoRouterState.of(context).pathParameters` and shows them in the placeholder body.

- [x] T068 [US2] Create skeleton `H:\alnujom-project\lib\features\locations\presentation\pages\location_form_page.dart`. (FR-014.) Renders a `Scaffold` with title built from the `mode` + `level` query parameters via `GoRouterState.of(context).uri.queryParameters['mode']` and `[...]['level']`. Body: placeholder text echoing the parsed params. The full form lands in T082.

- [x] T069 [US2] Register the 4 new routes in `H:\alnujom-project\lib\app.dart` (or the `lib\core\routing\app_router.dart` file — open both and choose the file where Phase 7 added the `/admin/super-admin/*` routes). Find that Phase 7 block (search for `/admin/super-admin`) and add the 4 new entries immediately below it. (FR-013.) Per `contracts\locations-routing.md`: `GoRoute(path: '/admin/locations', redirect: requireLocationsManageRedirect, builder: (_, __) => const LocationsListPage())`; `GoRoute(path: '/admin/locations/:governorateId', redirect: requireLocationsManageRedirect, builder: (_, state) => GovernorateDetailPage(governorateId: state.pathParameters['governorateId']!))`; `GoRoute(path: '/admin/locations/:governorateId/cities/:cityId', redirect: requireLocationsManageRedirect, builder: (_, state) => CityDetailPage(governorateId: ..., cityId: ...))`; `GoRoute(path: '/admin/locations/form', redirect: requireLocationsManageRedirect, builder: (_, state) => LocationFormPage(mode: ..., level: ..., id: state.uri.queryParameters['id'], parentId: state.uri.queryParameters['parentId']))`. The `requireLocationsManageRedirect` function comes from T070. Add imports for the four page files at the top of the route-config file.

- [x] T070 [US2] Extend `H:\alnujom-project\lib\core\routing\auth_redirect.dart`. (FR-013.) Add a NEW top-level function below `requireSuperAdminRedirect` (line 72 of the file): `String? requireLocationsManageRedirect(BuildContext context, GoRouterState state) { final checker = getIt<PermissionChecker>(); if (!checker.has(PermissionKeys.locationsManage)) { return '/admin'; } return null; }`. This mirrors the existing `requireSuperAdminRedirect` precedent (Phase 7) exactly — the redirect destination is `/admin` (the admin home), NOT `/home` or `/access-denied`. T069 wires this function into the per-route `redirect:` parameter on each of the 4 new locations routes. Do NOT modify the generic `authRedirect`/`_redirectAuthenticated` functions — the `/admin/*` admin-tier check already handles the broader case; the per-route locations check is the extra defense.

- [x] T071 [US2] Update `H:\alnujom-project\lib\features\admin\presentation\pages\admin_home_page.dart`. (FR-012.) Locate the existing super-admin tile insertion (search the file for `superAdminCategoryKeys` — Phase 7 added the tile that consults this constant). Immediately AFTER that tile's widget in the children list, add a new conditional tile. Pattern (adapt to the file's exact widget structure): `if (permissionChecker.has(PermissionKeys.locationsManage)) AdminHomeTile(icon: Icons.location_on_outlined, title: AppLocalizations.of(context).locationsTileTitle, onTap: () => context.go('/admin/locations')),` — substitute `AdminHomeTile` (or whatever the project's existing tile widget is called; Phase 6/7 named it consistently). The tile MUST be hidden (omitted from the children list entirely, not just dimmed) when the permission is absent — match Phase 7's `if (...) ...` pattern for the super-admin tile.

- [ ] T072 [US2] Manual device verification. (FR-012, FR-013, SC-008, SC-009, SC-010.) From `H:\alnujom-project`, build and run on the reference Infinix Note 8: `flutter run --dart-define-from-file=.env.json`. Sign in as a moderator account (Phase 6 §9.1 confirms moderator does NOT have `locations.manage`). Confirm: (a) admin home page renders without the Locations tile. (b) To test the route guard, temporarily add a debug action that calls `context.go('/admin/locations')` (a temporary `TextButton` on the home page, or invoke via `adb shell am start -a android.intent.action.VIEW -d "alnujom://admin/locations" <package>` if the project's `AndroidManifest.xml` declares the deep-link intent filter — check `android/app/src/main/AndroidManifest.xml` first) and confirm the redirect from T070's `requireLocationsManageRedirect` sends the user back to `/admin`. Remove the temporary debug action before the next step. Sign out. Sign in as the admin account (`locations.manage` is in the §9.1 mapping). Confirm: (a) admin home renders WITH the Locations tile; (b) tapping the tile opens the placeholder `LocationsListPage`; (c) the same debug action `context.go('/admin/locations/00000000-0000-0000-0000-000000000000')` now opens `GovernorateDetailPage` showing the placeholder UUID. Toggle device locale ar↔en mid-session — confirm the tile's label flips between "المواقع" and "Locations" (SC-010 for chrome strings; data labels are tested in T083).

**Checkpoint**: US2 verified independently. Admin tile gating + route guards in place. Pages are placeholders; content lands in US3+.

---

## Phase 7: User Story 3 — Governorate CRUD UI (Priority: P1)

**Goal**: Wire up `LocationsListPage` to display all governorates (with city counts) and add Create/Edit/Delete affordances for governorates. The seeded 14 rows are protected from delete (FR-015).

**Independent Test**: Open `LocationsListPage` on the admin device; confirm all 14 governorates render with their bilingual names and city counts; add a new custom governorate via the form; rename it; deactivate it; delete it. Confirm seeded rows show no Delete affordance.

- [x] T073 [US3] Create `H:\alnujom-project\lib\features\locations\presentation\bloc\locations_list_bloc.dart`. (FR-014.) Per `data-model.md` § 6.4. Events: `LoadRequested`, `RefreshRequested`. States: `Loading`, `Loaded(List<GovernorateWithCityCount>)`, `Error(String)`. On `LoadRequested`, calls `ListGovernorates(includeInactive: true)` (admin sees inactive rows). The page admin path always includes inactive; the LocationPicker (US6) calls with `includeInactive: false`. Apply `@injectable` annotation (no `as:`) for DI registration. **After authoring this file, re-run `flutter pub run build_runner build --delete-conflicting-outputs`** so `getIt<LocationsListBloc>()` resolves in T080. Failing to re-run codegen causes a runtime `Object/factory not registered` exception in T083 device walk.

- [x] T074 [US3] [P] Create `H:\alnujom-project\lib\features\locations\presentation\widgets\governorate_card.dart`. (FR-014, FR-015, FR-024.) Constructor: `const GovernorateCard({super.key, required this.summary, required this.onTap, required this.onEdit, required this.onToggleActive, this.onDelete});` where `summary` is a `GovernorateWithCityCount` and `onDelete` is `null` for `summary.governorate.isSystem == true` rows (FR-015: hide the affordance entirely). Body: a `ListTile` driven by Phase 2 design tokens — `leading: const Icon(Icons.location_on_outlined)`; `title: Text(summary.governorate.localizedName(Localizations.localeOf(context)))`; `subtitle: Text(AppLocalizations.of(context).subtitleCityCount(summary.cityCount))` (if the project's ARB pipeline supports ICU `{count}` plurals, use that; otherwise the bilingual_display_name_field.dart pattern); `trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (summary.governorate.isSystem) const SystemRowBadge(), if (!summary.governorate.isActive) const HiddenBadge(), PopupMenuButton<_CardAction>(...) ])`; `onTap: onTap`. PopupMenuButton items: `_CardAction.edit` (always), `_CardAction.toggleActive` (always), `_CardAction.delete` (only when `onDelete != null`). The widget itself does NOT navigate — it invokes the callbacks; T080 (the page) wires navigation. Add a missing `subtitleCityCount` ARB key to T063/T064 lists if not already there.

- [x] T075 [US3] [P] Create `H:\alnujom-project\lib\features\locations\presentation\widgets\system_row_badge.dart`. A small `Chip` widget with the `systemBadge` ARB-key label and a Phase 2 token color. Reused by `city_card.dart` later.

- [x] T076 [US3] [P] Create `H:\alnujom-project\lib\features\locations\presentation\widgets\hidden_badge.dart`. (FR-014, FR-024.) A small `Chip` widget rendering `AppLocalizations.of(context).hiddenBadge` with the muted/warning Phase 2 design token color (use `Theme.of(context).colorScheme.outline` or equivalent — do NOT use `Color(0xFF...)`). Mirrors `system_row_badge.dart` (T075) shape. Re-used across `governorate_card.dart`, `city_card.dart`, `area_card.dart`.

- [x] T077 [US3] [P] Create `H:\alnujom-project\lib\features\locations\presentation\widgets\bilingual_display_name_field.dart` per `contracts\locations-localization.md` § "BilingualDisplayNameField widget contract". (FR-016, FR-024, FR-023, Constitution V + VI.) Two `TextFormField`s (`ar` + `en`) stacked vertically per the updated contract. Arabic field is wrapped in `Directionality(textDirection: TextDirection.rtl, ...)` with the `displayNameArabicLabel` ARB key as label and a validator returning `AppLocalizations.of(context).arabicNameRequired` when empty after trim. English field is wrapped in `Directionality(textDirection: TextDirection.ltr, ...)` with `displayNameEnglishLabel` label and no validator. Emits `({String? arabic, String? english})` records via `onChanged` on every keystroke (Dart records — requires Dart 3+; pubspec confirms). Use `Theme.of(context).textTheme.*` and `kSpacing*` design tokens for spacing/typography — NO inline hex colors, NO `EdgeInsets.all(<int>)` magic numbers.

- [x] T078 [US3] [P] Create `H:\alnujom-project\lib\features\locations\presentation\widgets\delete_confirmation_dialog.dart` per `contracts\locations-admin-pages.md` § "Delete confirmation dialog". (FR-017, FR-024.) A function `Future<bool> showDeleteConfirmationDialog(BuildContext context, {required String title, Future<int>? dependentCountFuture, String? customMessage})` returning `true` on Confirm, `false` on Cancel/dismiss. Implementation: if `dependentCountFuture` is non-null, await it BEFORE calling `showDialog` and substitute the count into the appropriate ARB key (`deleteConfirmGovernorateWithDeps` for governorate-level callers — receives the combined cities+areas count; `deleteConfirmCityWithDeps` for city-level callers); if `dependentCountFuture` is null, use the generic `customMessage` or a localized "Are you sure?" string. Renders an `AlertDialog` (Phase 2 design token primitive) with localized Confirm/Cancel buttons. Use `Theme.of(context).colorScheme.error` for the destructive Confirm button — NO `Color(0xFFFF...)` literals.

- [x] T079 [US3] [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\count_governorate_dependents.dart`. (FR-017.) `@injectable class CountGovernorateDependents { final LocationsRepository repository; CountGovernorateDependents(this.repository); Future<({int cities, int areas})> call(String governorateId) async { final cities = await repository.countCitiesInGovernorate(governorateId); final areas = await repository.countAreasInGovernorate(governorateId); return (cities: cities, areas: areas); } }`. The `countCitiesInGovernorate` and `countAreasInGovernorate` repository methods are already declared in T039 (per data-model.md §6.2) and implemented in T059 step (9)/(10) and T060. This task only creates the use case wrapper. After authoring, **re-run `flutter pub run build_runner build --delete-conflicting-outputs`** so the new `@injectable` annotation registers with `getIt`.

- [x] T080 [US3] Fill in `H:\alnujom-project\lib\features\locations\presentation\pages\locations_list_page.dart`. (FR-014, FR-017.) Replace the placeholder body from T065 with: `BlocProvider(create: (_) => getIt<LocationsListBloc>()..add(LoadRequested()), child: BlocBuilder<LocationsListBloc, LocationsListState>(...))`. The builder renders the loading / error / loaded states. The loaded state shows a `ListView.separated` of `GovernorateCard` widgets ordered by the bloc's already-sorted list. A FloatingActionButton "Add governorate" navigates to `/admin/locations/form?mode=add&level=governorate`. Edit / Delete affordances on each card route to the form or trigger the delete dialog. The Delete dialog mounts `DeleteConfirmationDialog` (T078) with `dependentCountFuture: getIt<CountGovernorateDependents>().call(governorate.id).then((r) => r.cities + r.areas)` so the dialog displays the count.

- [x] T081 [US3] Create `H:\alnujom-project\lib\features\locations\presentation\bloc\location_form_bloc.dart` per `data-model.md` § 6.4. (FR-016.) Events: `FormOpened(LocationFormMode mode, LocationLevel level, String? id, String? parentId)`, `KeyChanged(String)`, `ArabicNameChanged(String)`, `EnglishNameChanged(String)`, `PositionChanged(int?)`, `IsActiveToggled(bool)`, `SaveRequested`. States: `Idle`, `Validating`, `Saving`, `SaveSuccess(entity)`, `SaveFailure(LocationsFailure)`. Define `enum LocationFormMode { add, edit }` and `enum LocationLevel { governorate, city, area }` in the same file. On `FormOpened` with mode=edit, calls the appropriate Load* use case to prefill. On `SaveRequested`, validates (Arabic name non-empty, key non-empty, key slug regex `^[a-z0-9][a-z0-9-]*$`) then calls the appropriate Create*/Update* use case based on `level` and `mode`. Error mapping per `data-model.md` § 10. Apply `@injectable` annotation. **After authoring this file, re-run `flutter pub run build_runner build --delete-conflicting-outputs`** so `getIt<LocationFormBloc>()` resolves in T082.

- [x] T082 [US3] Fill in `H:\alnujom-project\lib\features\locations\presentation\pages\location_form_page.dart`. (FR-014, FR-015, FR-016.) Replace the T068 placeholder. Parses `mode`, `level`, `id`, `parentId` from `GoRouterState.of(context).uri.queryParameters` (converting `mode` and `level` strings to the enum values defined in T081). Mounts `LocationFormBloc` via `BlocProvider(create: (_) => getIt<LocationFormBloc>()..add(FormOpened(mode, level, id, parentId)))`. Renders: AppBar with mode+level-appropriate title (from ARB keys); body = a `Form` containing a `TextFormField` for `key` (`enabled: !state.isLoadedSystemRow` — disabled when editing `is_system=true` row, per FR-015), a `BilingualDisplayNameField` (T077), an optional `TextFormField` for position (`keyboardType: TextInputType.number`), a `SwitchListTile` for is_active. Save button triggers `bloc.add(SaveRequested())`. On `SaveSuccess`, pops the route via `context.pop()`. On `SaveFailure`, shows a SnackBar with the mapped ARB-key message per `data-model.md` § 10 failure → ARB map.

- [ ] T083 [US3] Manual device verification. (FR-014, FR-015, FR-016, FR-017, SC-006, SC-007, SC-010, SC-013, SC-016, SC-017.) From the admin device: **start a stopwatch** at "tap the Locations tile" and stop it after the full add-then-delete loop below completes — the total elapsed time MUST be under 60 seconds for SC-006. Steps: tap Locations tile → `LocationsListPage` opens → confirm 14 governorate rows render with Arabic names + city counts. Toggle device locale to English → confirm names re-render (SC-010 for data labels). Tap "Add governorate" → fill `key=test-gov`, `ar=اختبار`, `en=Test`, position=99, isActive=true → Save → confirm row appears in the list. **SC-016 validation tests** (each must show a localized error, NOT save): try saving with empty `ar` field → expect `arabicNameRequired` message; try saving with empty `key` → expect `keyRequired`; try saving with `key=test-gov` again (duplicate) → expect `keyAlreadyUsed`. Tap the new row's PopupMenuButton → Edit → change English to "Test 2" → Save → confirm the list refreshes with the new name. Tap PopupMenuButton on Damascus → confirm Edit + Deactivate are present but Delete is ABSENT (SC-017). Tap the test-gov row's PopupMenuButton → Delete → confirm dialog appears showing "0 cities and 0 areas will also be deleted" → Confirm → confirm row disappears. Stop stopwatch — record elapsed time; if >60s, investigate UI-side bottlenecks before signing off SC-006. Verify via Supabase MCP `execute_sql`: `SELECT count(*) FROM public.governorates WHERE key='test-gov'` returns `0`; `SELECT action FROM public.audit_logs WHERE action='governorate.deleted' AND actor_user_id IS NOT NULL ORDER BY occurred_at DESC LIMIT 1` returns one row with the admin's UUID in `actor_user_id` (SC-013 in-app actor recorded).

**Checkpoint**: US3 verified independently. Governorate CRUD works on the device; system-row protection enforced UI-side AND server-side (T025 already verified).

---

## Phase 8: User Story 4 — City CRUD UI (Priority: P1)

**Goal**: Wire up `GovernorateDetailPage` to display cities for a governorate (with area counts) and add Create/Edit/Delete affordances. Seeded cities (`is_system=true`) hide their Delete affordance.

**Independent Test**: Tap any governorate from `LocationsListPage` → `GovernorateDetailPage` opens listing the seeded cities; add a custom city; rename; delete. Confirm seeded cities show no Delete.

- [x] T084 [US4] Create `H:\alnujom-project\lib\features\locations\presentation\bloc\governorate_detail_bloc.dart` per `data-model.md` § 6.4. (FR-014.) Events: `LoadRequested(String governorateId)`, `RefreshRequested`. States: `Loading`, `Loaded(Governorate, List<CityWithAreaCount>)`, `Error`. On `LoadRequested`, calls `LoadGovernorateDetail(id)` AND `ListCitiesForGovernorate(governorateId: id, includeInactive: true)` in parallel (via `Future.wait`); combines into the `Loaded` state. Apply `@injectable` annotation. **After authoring this file, re-run `flutter pub run build_runner build --delete-conflicting-outputs`** so `getIt<GovernorateDetailBloc>()` resolves in T088.

- [x] T085 [US4] [P] Create `H:\alnujom-project\lib\features\locations\presentation\widgets\city_card.dart`. (FR-014, FR-015, FR-024.) Constructor: `const CityCard({super.key, required this.summary, required this.onTap, required this.onEdit, required this.onToggleActive, this.onDelete});` where `summary` is a `CityWithAreaCount` and `onDelete` is `null` when `summary.city.isSystem == true`. Body mirrors `governorate_card.dart` (T074) exactly with `summary.city.localizedName(...)` for title and an area-count subtitle (`subtitleAreaCount` ARB key — add to T063/T064 if missing). Same callback pattern; same Phase 2 design tokens; no inline navigation.

- [x] T086 [US4] [P] Confirm `countAreasInCity` is implemented in T059 step (11) and exposed on `LocationsRepository` per T039 (data-model.md §6.2 enumerates it). If missing for any reason, add it now: SQL pattern `.from('areas').select('id', const FetchOptions(count: CountOption.exact, head: true)).eq('city_id', cityId)` returning `response.count ?? 0`. Otherwise this task is a no-op verification step.

- [x] T087 [US4] [P] Create `H:\alnujom-project\lib\features\locations\domain\usecases\count_city_dependents.dart`. (FR-017.) `@injectable class CountCityDependents { final LocationsRepository repository; CountCityDependents(this.repository); Future<int> call(String cityId) => repository.countAreasInCity(cityId); }`. After authoring, **re-run `flutter pub run build_runner build --delete-conflicting-outputs`** so the new `@injectable` annotation registers with `getIt`.

- [x] T088 [US4] Fill in `H:\alnujom-project\lib\features\locations\presentation\pages\governorate_detail_page.dart`. (FR-014, FR-015, FR-017.) Replace T066 placeholder. Reads `:governorateId` from `GoRouterState.of(context).pathParameters['governorateId']`. Mounts `GovernorateDetailBloc` via `BlocProvider(create: (_) => getIt<GovernorateDetailBloc>()..add(LoadRequested(governorateId)))`. Builder renders the header (governorate's localized name + system/hidden badges + an "Edit governorate" affordance routing to `/admin/locations/form?mode=edit&level=governorate&id=<governorateId>`) and the cities list (a `ListView.separated` of `CityCard`s — T085 — ordered per bloc state). FAB "Add city" routes to `/admin/locations/form?mode=add&level=city&parentId=<governorateId>`. Edit/Delete affordances on each card route to the form or trigger the dialog. The Delete dialog mounts `DeleteConfirmationDialog` (T078) with `dependentCountFuture: getIt<CountCityDependents>().call(city.id)` so the dialog displays the count.

- [x] T089 [US4] Extend `LocationFormBloc` (T081) to handle `level=city`. (FR-014, FR-016.) On `FormOpened` with `level=city`, when mode=add the form requires `parentId` (the governorateId) — if missing, emit `SaveFailure(LocationsFailure.unknown('parentId required for city add'))`; when mode=edit, loads the city via `LoadCityDetail(id)`. On `SaveRequested` with level=city, calls `CreateCity` or `UpdateCity` use case. The key-uniqueness scope is per-governorate (`UNIQUE(governorate_id, key)` per `data-model.md` § 1.2) — the Supabase error for a duplicate key returns `23505` with the `cities_unique_key_per_governorate` constraint name; map to `LocationsFailure.KeyAlreadyUsed` with the localized message. After editing T081, no `build_runner` re-run needed (no new `@injectable` annotation — just bloc logic extension).

- [ ] T090 [US4] Manual device verification. (FR-014, FR-015, FR-017, SC-013, SC-017.) From admin device: tap Damascus on `LocationsListPage` → `GovernorateDetailPage` opens listing seeded Damascus cities (the inventory in `data-model.md` § 5.2 has just `damascus` under governorate `damascus`). Tap "Add city" → fill `key=jaramana`, bilingual name (`ar=جرمانا`, `en=Jaramana`), save → confirm appears. Edit it → save → confirm. Tap Delete → confirm dialog shows "0 areas will also be deleted" → confirm → row disappears. Confirm seeded city `damascus` (the city named the same as the governorate) shows Edit + Deactivate but NO Delete affordance (SC-017). Verify via SQL: `SELECT key FROM public.cities WHERE governorate_id=(SELECT id FROM public.governorates WHERE key='damascus') AND key='jaramana'` returns 0 rows post-delete; `SELECT action, actor_user_id FROM public.audit_logs WHERE action IN ('city.created','city.deleted') ORDER BY occurred_at DESC LIMIT 2` shows both rows with the admin's UUID in `actor_user_id` (SC-013 in-app actor recorded).

**Checkpoint**: US4 verified independently. City CRUD works; system-row protection holds.

---

## Phase 9: User Story 5 — Area CRUD UI (Priority: P2)

**Goal**: Wire up `CityDetailPage` to display areas for a city, with full CRUD (areas have no system protection per FR-015).

**Independent Test**: Tap any city from `GovernorateDetailPage` → `CityDetailPage` opens listing seeded areas (may be empty); add an area; rename; delete. Every area row exposes Delete (no protection).

- [x] T091 [US5] Create `H:\alnujom-project\lib\features\locations\presentation\bloc\city_detail_bloc.dart` per `data-model.md` § 6.4. (FR-014.) Events: `LoadRequested(String cityId)`, `RefreshRequested`. States: `Loading`, `Loaded(City, List<Area>)`, `Error`. On `LoadRequested`, calls `LoadCityDetail(id)`, `LoadGovernorateDetail(city.governorateId)` (for the breadcrumb), AND `ListAreasForCity(cityId: id, includeInactive: true)` in parallel via `Future.wait`. The `Loaded` state carries the city, its governorate (for breadcrumb), and the areas list. Apply `@injectable` annotation. **After authoring this file, re-run `flutter pub run build_runner build --delete-conflicting-outputs`** so `getIt<CityDetailBloc>()` resolves in T093.

- [x] T092 [US5] [P] Create `H:\alnujom-project\lib\features\locations\presentation\widgets\area_card.dart`. (FR-014, FR-024.) Constructor: `const AreaCard({super.key, required this.area, required this.onEdit, required this.onToggleActive, required this.onDelete});` — `onDelete` is non-nullable because areas have no protected seed (FR-015 carve-out: every area row exposes Delete). Body mirrors `city_card.dart` (T085) minus the count subtitle (areas have no children — show `area.description` if non-null OR omit subtitle entirely) and minus the system_row_badge logic (no `is_system` field on areas). Hidden badge when `!area.isActive`. PopupMenuButton always shows all three options. Same Phase 2 design tokens; no inline navigation.

- [x] T093 [US5] Fill in `H:\alnujom-project\lib\features\locations\presentation\pages\city_detail_page.dart`. (FR-014, FR-017.) Replace T067 placeholder. Reads `:governorateId` and `:cityId` from `GoRouterState.of(context).pathParameters`. Mounts `CityDetailBloc` via `BlocProvider(create: (_) => getIt<CityDetailBloc>()..add(LoadRequested(cityId)))`. Renders: AppBar with the city's localized name; body shows a breadcrumb header `"${governorate.localizedName(locale)} → ${city.localizedName(locale)}"` using the governorate from the `Loaded` state (T091 already fetches it); then the areas list (`ListView.separated` of `AreaCard`s — T092). FAB "Add area" routes to `/admin/locations/form?mode=add&level=area&parentId=<cityId>`. The Delete dialog on each area uses `DeleteConfirmationDialog` (T078) with `dependentCountFuture: null` (areas have no children — the dialog renders the generic confirm message without dependent counts).

- [x] T094 [US5] Extend `LocationFormBloc` (T081, T089) to handle `level=area`. (FR-014, FR-016.) Symmetric to T089: `parentId` is the cityId; calls `CreateArea`/`UpdateArea`. Uniqueness scope is per-city (constraint `areas_unique_key_per_city` — map 23505 with this constraint name to `LocationsFailure.KeyAlreadyUsed`). No `build_runner` re-run needed (bloc-logic-only change).

- [ ] T095 [US5] Manual device verification. (FR-014, FR-015, FR-017, SC-013.) From admin device: tap any city (e.g., Damascus city) on `GovernorateDetailPage` → `CityDetailPage` opens listing seeded areas (Old City Damascus, Mezzeh, Mashrouh Dummar per the planned seed inventory in `data-model.md` § 5.3). Tap "Add area" → fill `key=jaramana-center`, bilingual name (`ar=وسط جرمانا`, `en=Jaramana Center`), save → confirm appears. Edit → confirm. Delete → confirm dialog (generic message, no dependent counts since areas have no children) → Confirm → confirm disappears. **Crucially**, pick one of the seeded areas (e.g., Mezzeh) and confirm its PopupMenuButton DOES expose Delete (areas have no `is_system` protection per FR-015 and US5). Cancel the delete on the seeded area (do not actually delete to preserve the seed). Verify audit: `SELECT action, actor_user_id FROM public.audit_logs WHERE action IN ('area.created','area.deleted') ORDER BY occurred_at DESC LIMIT 2` shows both rows with admin's UUID (SC-013).

**Checkpoint**: US5 verified independently. Area CRUD works; every area row is fully mutable.

---

## Phase 10: User Story 6 — LocationPicker widget + smoke-test surface (Priority: P1)

**Goal**: Ship the reusable `LocationPicker` widget that Phase 10's listing form will consume. The widget cascades governorate → city → area with locale-fallback rendering and `is_active=true` filtering.

**Independent Test**: Mount the LocationPicker on a dev-only smoke-test screen; confirm cascading works for all 14 governorates and that selecting a city with zero seeded areas shows the "no areas yet" affordance.

- [x] T096 [US6] Create `H:\alnujom-project\lib\features\locations\presentation\bloc\location_picker_bloc.dart` per `data-model.md` § 6.4 and `contracts\location-picker-widget.md` § "Behavior contract". (FR-018, FR-019, FR-020, FR-022.) Events: `MountRequested`, `GovernoratePicked(String id)`, `CityPicked(String id)`, `AreaPicked(String? id)`, `Reset`. States: `Initial`, `GovernoratesLoading`, `GovernoratesLoaded(List<Governorate>)`, `CitiesLoading(String governorateId)`, `CitiesLoaded(...)`, `AreasLoading(String cityId)`, `AreasLoaded(...)`, `SelectionCommitted(LocationPickerSelection)`. All use case calls use `includeInactive: false` per FR-020 / R-17. Apply `@injectable` annotation (factory scope — each `LocationPicker` mount gets its own bloc instance). **After authoring this file, re-run `flutter pub run build_runner build --delete-conflicting-outputs`** so `getIt<LocationPickerBloc>()` resolves in T098.

- [x] T097 [US6] [P] Create `H:\alnujom-project\lib\features\locations\presentation\widgets\location_picker_dropdown.dart`. A `DropdownButtonFormField<T>` primitive consuming Phase 2 design tokens. Renders an option list with each option's `localizedName(locale)`. Used by `LocationPicker` (T098) for each of the 3 cascade levels.

- [x] T098 [US6] Create `H:\alnujom-project\lib\features\locations\presentation\widgets\location_picker.dart` per `contracts\location-picker-widget.md` § "Public API". (FR-018, FR-019, FR-020, FR-021, FR-022.) Constructor: `const LocationPicker({super.key, this.initialSelection, required this.onChanged, this.required = false, this.areaRequired = false});`. The widget wraps `BlocProvider(create: (_) => getIt<LocationPickerBloc>()..add(const MountRequested()), child: BlocConsumer<LocationPickerBloc, LocationPickerState>(listener: ..., builder: ...))`. The `listener` calls `widget.onChanged(state.selection)` whenever the state changes to `SelectionCommitted`. Builder: renders three `LocationPickerDropdown`s (governorate, city, area) using the bloc state; the second is disabled until governorate is picked; the third is disabled until city is picked AND if the loaded `Areas` list is empty, renders a localized "no areas yet — leave blank" affordance (`locationPickerNoAreasYet` ARB key) per FR-019. When governorate is reset (`Reset` event), the listener fires `widget.onChanged(null)`.

- [x] T099 [US6] [P] Create a smoke-test surface at `H:\alnujom-project\lib\features\locations\presentation\pages\location_picker_smoke_test_page.dart` (per R-21). A `StatefulWidget` `Scaffold` with an `AppBar` (title `'LocationPicker smoke test'` — this is dev-only so a hardcoded English string is acceptable; do NOT add an ARB key for it) and a body `Column` containing the `LocationPicker` widget (with `onChanged: (sel) => setState(() => _latest = sel)`) plus a `Text` widget below it rendering `_latest == null ? 'no selection' : 'gov=${_latest!.governorateId} city=${_latest!.cityId} area=${_latest!.areaId ?? "null"}'`. Wire up the route in `H:\alnujom-project\lib\app.dart` (or wherever the `GoRouter` `routes:` list is constructed). Use a spread pattern with a `kDebugMode` guard: in the `routes:` list, add `...(kDebugMode ? [GoRoute(path: '/dev/locations-picker', builder: (_, __) => const LocationPickerSmokeTestPage())] : <RouteBase>[])`. The `if (kDebugMode) GoRoute(...)` pattern is NOT valid inside a const list literal — only the spread-with-conditional form compiles. Add `import 'package:flutter/foundation.dart' show kDebugMode;` if not already present. This page is throwaway scaffolding for Phase 8 verification; Phase 13 will become the canonical consumer (per spec Assumptions).

- [ ] T100 [US6] Manual device verification. (FR-018, FR-019, FR-020, FR-022, SC-011, SC-012, SC-015.) From the admin device, navigate to `/dev/locations-picker`. Confirm: (a) Governorate dropdown lists all 14 governorates in editorial order with Damascus first; (b) tap Damascus → city dropdown populates with seeded Damascus city(ies); (c) tap a city → area dropdown populates with seeded areas, OR the "no areas yet" affordance appears; (d) tap an area → `Text` debug shows `gov=<uuid> city=<uuid> area=<uuid>`; (e) reset and pick Aleppo → city dropdown re-populates with Aleppo cities (Damascus's cities are gone); (f) pick a city with zero seeded areas → confirm the no-areas-yet affordance + the debug text shows `area=null`; (g) toggle locale ar↔en → confirm labels flip without losing selection state. **SC-015 deactivation test**: navigate back to the admin pages → open `LocationsListPage` → Damascus → pick any seeded Damascus city (e.g., the `damascus` row) → PopupMenuButton → Deactivate. Re-open `/dev/locations-picker` → pick Damascus → confirm the deactivated city is ABSENT from the city dropdown (the LocationPicker filters `is_active=true` per FR-020). Return to the admin page and Reactivate the city to restore the seed state. Verify in admin page the city carries a "Hidden" badge while deactivated.

- [ ] T101 [US6] **[HUMAN-ONLY — skip if no second device available; the human reviewer runs this step at PR review time]** Verify the cross-device rename propagation (FR-011, SC-007, SC-021, R-20). On the admin device, edit Latakia's English `display_name` to "Latakia City" via the admin form. On a separate test device signed in as a regular `user`-only account, open `/dev/locations-picker` (or, if the test account doesn't see the dev-only route, mount the picker via a quick debug widget). Within 5 seconds of foregrounding, confirm "Latakia City" appears in the governorate dropdown. Then revoke `locations.manage` from the admin role via Phase 7's `RoleEditorPage` on a third browser session; confirm the Locations tile disappears from the admin device's home page within seconds of foreground resume (no sign-out required) — this verifies SC-021 mid-session propagation. Re-grant the permission; confirm the tile reappears. Restore Latakia's name to "Latakia". A cheap LLM implementer is NOT expected to execute this task — flag it for the human reviewer in the PR description.

**Checkpoint**: US6 verified independently. The reusable LocationPicker is shipped and ready for Phase 10's listing form to import.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup, full-spec verification, DEFERRED.md authoring, lint and design-token audits.

- [ ] T102 Run the full `quickstart.md` verification recipe end-to-end (Steps 1–12) against the device + remote project. Record each step's pass/fail in a per-step note. Resolve any failure before moving to T103. The per-FR / per-SC verification map at the bottom of `quickstart.md` MUST show every requirement verified.

- [x] T103 [P] Run the Phase 3 localization lint guard. (SC-020, Constitution V.) From `H:\alnujom-project`, run the project's localization-check command (find it in the existing CI workflow `.github/workflows/*.yml` or in a `tool/` script; Phase 3 introduced it — common names: `tool/check_localization.dart`, `tool/lint_l10n.sh`). Confirm zero hardcoded user-facing strings in any file under `lib/features/locations/`. The smoke-test page (T099) is the one allowed exception — it has the `'LocationPicker smoke test'` hardcoded AppBar title since it's dev-only. If any other hardcoded user-facing string is found, replace with `AppLocalizations.of(context).<key>` and re-run until clean.

- [x] T104 [P] Design-token audit. (SC-019, FR-024, Constitution VI.) Run `grep -R "Color(0xFF" lib/features/locations/` and `grep -R "EdgeInsets.all([0-9]" lib/features/locations/` (PowerShell: `Get-ChildItem lib/features/locations -Recurse -Include *.dart | Select-String 'Color\(0xFF|EdgeInsets\.all\([0-9]'`). Expected: zero matches. If any inline color or padding magic numbers are found, replace with the appropriate Phase 2 design token (`Theme.of(context).colorScheme.*` or `kSpacing*` constants) and re-run until clean.

- [x] T105 [P] Constitution IX boundary audit. Run `grep -R "package:supabase_flutter" lib/features/locations/domain/` and `grep -R "package:supabase_flutter" lib/features/locations/presentation/`. Expected: zero matches in both. If any found, the import has leaked across the Clean Architecture boundary — move the Supabase-touching code into `data/` and consume an abstract type from `domain/`.

- [x] T106 [P] Re-run `flutter analyze` from `H:\alnujom-project`. Expected: zero new analyzer warnings introduced by Phase 8. Any pre-existing warnings from Phases 1–7 are out of scope (do NOT fix here).

- [x] T107 Run `flutter pub run build_runner build --delete-conflicting-outputs` one more time to ensure DI codegen is current with any late additions in T080/T086/T087 (the count-dependents use cases). Verify `lib/core/di/injection.config.dart` references all new use cases.

- [x] T108 Final advisor sweep. Run Supabase MCP `get_advisors` type=`security` AND `get_advisors` type=`performance`. Confirm zero NEW entries introduced by Phase 8 beyond what was already accepted at T018. Index advisor entries should be clean (T015's `idx_*` indexes cover the FK and is_active query patterns).

- [x] T109 Author `H:\alnujom-project\specs\008-locations\DEFERRED.md` (mirror of Phase 7's `specs/007-super-admin-roles/DEFERRED.md`). If any scope was intentionally deferred during implementation (e.g., the choice between dev-only smoke-test surface vs admin-side picker preview from R-21; any seed-row inventory adjustment; any ARB-key copy that needs a follow-up review), enumerate the row + rationale + proposed follow-up spec. If nothing was deferred, write a single line: "No work deferred. Phase 8 ships complete per spec." Per project memory `project_deferred_work.md`, this file is reviewed at squash-merge time.

- [x] T110 (Optional) Author `H:\alnujom-project\specs\008-locations\HANDOFF.md` if any work is in flight at close-out (e.g., a partially-authored second-tier city that needs name verification). Omit if Phase 8 ships clean. Per project memory `project_deferred_work.md`.

**Checkpoint**: Phase 8 is complete. The PR is ready for squash-merge into `main`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — can start immediately.
- **Phase 2 (Foundational Backend)**: Depends on Phase 1 completion. BLOCKS all user-story phases.
- **Phase 3 ([US7] Backend verification)**: Depends on Phase 2. Pure SQL verification — no Flutter work.
- **Phase 4 ([US1] Public-read verification)**: Depends on Phase 2. Pure SQL verification.
- **Phase 5 (Foundational Flutter data layer)**: Depends on Phase 2 (the migrations must exist for the datasource to query). Parallelizable across the T032–T064 file authoring (most are [P]).
- **Phase 6 ([US2] Admin tile + routes)**: Depends on Phase 5.
- **Phase 7 ([US3] Governorate CRUD UI)**: Depends on Phase 6.
- **Phase 8 ([US4] City CRUD UI)**: Depends on Phase 7 (extends `LocationFormBloc` from T081).
- **Phase 9 ([US5] Area CRUD UI)**: Depends on Phase 8 (further extends `LocationFormBloc`).
- **Phase 10 ([US6] LocationPicker)**: Depends on Phase 5 ONLY (the picker uses the shared data layer; it does NOT depend on the admin pages). Could in principle run parallel to Phases 6–9 if a second developer is available.
- **Phase 11 (Polish)**: Depends on all prior phases.

### Within Each Phase

- Setup tasks marked [P] can run in parallel (T002/T003/T004).
- Foundational backend migrations are strictly sequential by filename (T006 → T007 → T009 → T010 → T012 → T013 → T015 → T016 → T017 → T018), but the parallel policy-file authoring (T008, T011, T014) and the doc files (T019, T020, T021) can run in parallel within their respective slots.
- Foundational Flutter layer (Phase 5) is mostly parallel — all entity files (T032–T038), all use case files (T040–T053), and all DTO files (T054–T058) are [P] within their groups. The datasource (T059) and repository impl (T060) must come after the DTOs and entities.
- Each user-story phase: the bloc (e.g., T073) must precede the page that mounts it (T079). Widgets ([P]) can be authored in parallel.

### Parallel Opportunities

- Phase 1: T002 + T003 + T004 in parallel.
- Phase 2: While T006/T007 run (sequential), T008 can be authored in parallel. Same shape for T009/T010 + T011, and T012/T013 + T014. T019/T020/T021 fully parallel.
- Phase 5: ~25 of the 33 tasks are [P]. A single agent can author all entity files in parallel, then all use case files in parallel, then all DTO files in parallel.
- Phase 7: T074/T075/T076/T077/T078 + T080 are [P]. T079, T081, T082 sequential within the phase.
- Phase 8: T085/T086/T087 [P]. T088, T089 sequential.
- Phase 11: T103, T104, T105, T106 fully parallel.

### Per-Story Independent Test Criteria

- **US1**: Anonymous + signed-in clients return the full seed via SELECT (T029, T030, T031).
- **US2**: Moderator sees no Locations tile; admin sees + can navigate to placeholder pages (T072).
- **US3**: Admin creates / edits / deletes a custom governorate; seeded governorates show no Delete (T083).
- **US4**: Admin creates / edits / deletes a custom city; seeded cities show no Delete (T090).
- **US5**: Admin creates / edits / deletes an area; every area exposes Delete (T095).
- **US6**: LocationPicker cascades correctly; locale toggle preserves selection; rename propagates within 5s (T100, T101).
- **US7**: Audit triggers fire on every mutation; immutability triggers refuse protected ops; idempotency confirmed (T023–T028).

---

## Implementation Strategy

### MVP First (Foundational + US1 + US2 + US3 only)

If a partial-Phase-8 demo is required:

1. Complete Phases 1–2 (setup + backend migrations + advisor hardening).
2. Run Phases 3–4 ([US7] + [US1] backend verification).
3. Complete Phase 5 (Flutter data layer).
4. Complete Phase 6 ([US2] tile + routes).
5. Complete Phase 7 ([US3] governorate CRUD UI).
6. STOP. Demo the admin's governorate-CRUD path + the seeded catalog visible via direct SQL.
7. The remaining stories (US4 cities, US5 areas, US6 picker) can ship in a follow-up PR.

### Recommended Path (Full Phase 8 in one PR)

Per project memory `feedback_git_workflow.md`, the project ships one PR per spec, not per phase:

1. Complete Phases 1–11 in order.
2. Author DEFERRED.md / HANDOFF.md as the final step.
3. Open a single PR titled "Phase 8 — Locations Catalog (Governorates, Cities, Areas)".
4. Reviewer runs the `quickstart.md` recipe end-to-end before approval.
5. Squash-merge to `main`.

### Parallel Team Strategy (if multiple developers available)

After Phase 5 completes:

- Developer A: Phases 6 + 7 + 8 + 9 (the admin CRUD chain).
- Developer B: Phase 10 ([US6] LocationPicker, depends on Phase 5 only).
- Developer C: Phase 11 polish + DEFERRED authoring (runs in parallel with A and B for the parts that don't depend on completed UI).

---

## Notes

- [P] tasks = different files, no dependencies. Run them in parallel within their phase if your environment supports it.
- [Story] label maps each task to a user story for traceability with the spec.
- Each user story phase ends in a checkpoint test that can demo the increment independently.
- Verify against SQL queries from `quickstart.md` rather than reading the Phase 8 migration files — the migrations are the source of truth, but the SQL queries are what acceptance demands.
- Commit after each logical group (e.g., after T007, after T018, after T028, etc.) per `feedback_git_workflow.md`.
- The 30–40 city seed inventory in `data-model.md` § 5.2 is a planning target; the actual final count may shift by ±2 rows at the migration author's discretion within the band.
- The starter areas seed in § 5.3 is a planning target; actual final count may vary.
- DO NOT introduce new permission keys (FR-010); DO NOT introduce new packages (`pubspec.yaml` is frozen for Phase 8); DO NOT introduce new automated tests (`feedback_no_new_tests.md`).
- The `LocationsListPage`, `GovernorateDetailPage`, `CityDetailPage`, and `LocationFormPage` files are touched by multiple phases (skeleton in US2, filled in US3/US4/US5). This is intentional — the skeleton is the route-guard verification surface; the fill is the story-specific functionality. Do NOT try to fully populate the pages in US2.
- When a task says "per `contracts/X.md` § Y", that section is the source of truth. The contracts are dense; read the relevant section completely before authoring.
- The `BilingualDisplayNameField` widget (T077) is reused across US3, US4, US5 form modes — do NOT duplicate it.
- The `DeleteConfirmationDialog` widget (T078) is reused across all three levels — do NOT duplicate.
- If you discover during implementation that a contract is ambiguous or a data-model spec is unclear, STOP and update the relevant file in the same PR (Principle X: drift between specs and code is a defect).
