---
description: "Phase 6 — Roles & Permissions task list (no automated tests per durable session feedback)"
---

# Tasks: Roles & Permissions

**Input**: Design documents from `/specs/006-roles-permissions/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: NO automated tests are generated in this phase. Per `feedback_no_new_tests.md` (durable session feedback carried forward from Phases 3/4/5) and the spec's "No new automated tests" assumption, all verification is manual SQL via Supabase MCP `execute_sql` + Supabase MCP `get_advisors` after each migration + manual UI walk on the reference Infinix Note 8 device, all walked by `quickstart.md`. Existing Phase 1/2/3/4/5 tests remain in source unchanged.

**Organization**: Tasks are grouped by user story so US1 / US2 / US3 / US4 / US5 are each independently completable + verifiable. The **MVP scope is the Foundational phase plus US2** (the backfill migration + entity-field removal is non-negotiable — without it, Phase 5's admin queue breaks). US1 verifies the foundational seeds; US3 / US4 / US5 ship as additive increments on top of US2.

**Format**: `- [ ] [TaskID] [P?] [Story?] Description with file path`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: One-time scaffolding + baseline capture before migrations land.

- [X] T001 Capture the pre-migration baseline counts (per `quickstart.md` Step 1) for use in the backfill verification: run `SELECT count(*) FROM public.profiles WHERE is_admin = TRUE` (save as **N_pre_admin**), `SELECT count(*) FROM public.profiles` (save as **M_profiles**), `SELECT user_id FROM public.profiles WHERE is_admin = TRUE ORDER BY user_id` (save as **L_admin_pre**). Document the three values in `specs/006-roles-permissions/baseline-pre-migration.txt` (a gitignored scratch file or a note pasted into the PR description) so US2 can verify the backfill conversion count.
- [X] T002 Confirm Phase 5 baseline is intact (Phase 6 builds on top of it). Run via Supabase MCP `execute_sql`:
  ```sql
  -- (a) is_admin column still exists
  SELECT column_name FROM information_schema.columns
   WHERE table_schema='public' AND table_name='profiles' AND column_name='is_admin';
  -- Expected: 1 row

  -- (b) current_user_is_admin() body is the Phase 5 column-read shape (will be swapped by T018 later)
  SELECT pg_get_functiondef('public.current_user_is_admin()'::regprocedure);
  -- Expected: body contains "is_admin FROM profiles" per Phase 5 R-12

  -- (c) account_approval_requests table exists
  SELECT to_regclass('public.account_approval_requests');
  -- Expected: 'account_approval_requests' (non-NULL)

  -- (d) At least one user has is_admin = TRUE (the Phase 5 admin)
  SELECT count(*) FROM public.profiles WHERE is_admin = TRUE;
  -- Expected: ≥ 1
  ```
  If (d) returns 0, bootstrap a Phase 5 admin via privileged SQL BEFORE proceeding (this is operationally a Phase 5 follow-up but must be done now if missed):
  ```sql
  UPDATE public.profiles SET is_admin = TRUE WHERE user_id = '<chosen-admin-uuid>' RETURNING user_id, is_admin;
  -- Expected: 1 row, is_admin = true.
  ```
  Choose `<chosen-admin-uuid>` operationally (the project owner's auth user_id is the typical choice). Document the chosen user in the project runbook.
- [X] T003 [P] Create empty Phase 6 source-tree scaffolds with `.gitkeep` files: `lib/core/security/`, `lib/features/admin/presentation/pages/` (alongside the existing `lib/features/admin/account_approvals/` from Phase 5). Empty folders do not survive `git add` without `.gitkeep`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The eight Phase 6 migrations (1–6 + 8 — migration 7 lands under US2 because the column drop is US2's atomic action) + the five policy files + the Flutter `PermissionChecker` + the `PermissionKeys` constants + the `PermissionCatalogRepository` abstract+impl + the DI registration + the ARB keys.

**⚠️ CRITICAL**: No user story work can begin until Phase 2 completes. US1's verification is folded into the foundational seed inspection. US2 cannot run its backfill migration until migration 6 (the body-swap) lands. US3/US4/US5 cannot wire their Flutter surfaces until the PermissionChecker exists.

### Backend SQL — `roles` table + system-role-immutability trigger + seed (R-01, R-06, FR-001, FR-002, FR-020)

- [X] T004 Author `supabase/policies/roles_policies.sql` with one SELECT policy: `roles_read_all_authenticated` (`FOR SELECT TO authenticated USING (TRUE)`). Wrapped in `DROP POLICY IF EXISTS … CREATE POLICY …` for idempotency. No INSERT/UPDATE/DELETE policy (mutation lands in Phase 7).
- [X] T005 Author `supabase/migrations/20260515120001_create_roles.sql` containing: the `roles` table per `data-model.md` "roles" schema; `ENABLE ROW LEVEL SECURITY`; the bundled policy bodies from `supabase/policies/roles_policies.sql` (with `-- generated from supabase/policies/roles_policies.sql` header comment per Phase 4 R-02 inline-policy bundling); `enforce_role_system_immutability()` function + `trg_roles_enforce_system_immutability` trigger per `contracts/system-role-immutability-trigger.md`; `set_updated_at` BEFORE UPDATE trigger (reusing Phase 4's helper); the seed block inserting the seven system roles (`user`, `owner`, `agent`, `agency_admin`, `moderator`, `admin`, `super_admin`) with bilingual `display_name` JSONB per `data-model.md` "Seeded role catalog", wrapped in `INSERT … ON CONFLICT (key) DO NOTHING`.
- [X] T006 Apply `20260515120001_create_roles.sql` via Supabase MCP `apply_migration` against the remote project. Verify per `quickstart.md` Step 3: `SELECT count(*) FROM public.roles WHERE is_system = TRUE` returns 7; the seven keys match the expected list; the `display_name->>'ar'` and `display_name->>'en'` values are populated. Then attempt `DELETE FROM public.roles WHERE key = 'user'` and confirm `42501` is raised (system-role-immutability trigger fires). Run Supabase MCP `get_advisors` with `type: 'security'` and note any new warnings (the trigger function declares `LANGUAGE plpgsql` without explicit `SET search_path` — this is the migration-8 hardening target).

### Backend SQL — `permissions` table + seed (R-01, FR-003, FR-004)

- [X] T007 [P] Author `supabase/policies/permissions_policies.sql` with one SELECT policy: `permissions_read_all_authenticated`. Wrapped idempotently. No write policies.
- [X] T008 Author `supabase/migrations/20260515120002_create_permissions.sql` containing: the `permissions` table per `data-model.md` "permissions" schema (no `updated_at`); `ENABLE RLS`; the bundled policy bodies from `supabase/policies/permissions_policies.sql`; the seed block inserting the 24 keys from §9.1 (full list in `data-model.md` "Seeded permission catalog") with their `category` values, wrapped in `INSERT … ON CONFLICT (key) DO NOTHING`.
- [X] T009 Apply `20260515120002_create_permissions.sql` via Supabase MCP `apply_migration`. Verify per `quickstart.md` Step 4: `SELECT count(*) FROM public.permissions` ≥ 24; the per-category breakdown matches the expected counts (`users:4, listings:5, roles:5, locations:1, currencies:1, ads:1, reports:1, agencies:3, settings:1, audit:1, inquiries:1`); `SELECT key FROM public.permissions WHERE category = 'users'` returns the four `users.*` keys. Run `get_advisors` — no new warnings expected for this migration.

### Backend SQL — `role_permissions` table + seed (R-04, FR-005, FR-006)

- [X] T010 [P] Author `supabase/policies/role_permissions_policies.sql` with one SELECT policy: `role_permissions_read_all_authenticated`. Wrapped idempotently. No write policies.
- [X] T011 Author `supabase/migrations/20260515120003_create_role_permissions.sql` containing: the `role_permissions` table per `data-model.md` "role_permissions" schema (composite PK, ON DELETE CASCADE on role_id, ON DELETE RESTRICT on permission_id); `ENABLE RLS`; the bundled policy bodies; the three seed blocks per `data-model.md` "Seeded role-permission mappings" — moderator 5 rows, admin 16 rows (per R-04: includes `agencies.view` + `inquiries.view_all` beyond §9.1's literal 15), super_admin all 24 rows via `SELECT FROM permissions`. Each `INSERT` uses `ON CONFLICT (role_id, permission_id) DO NOTHING`.
- [X] T012 Apply `20260515120003_create_role_permissions.sql` via Supabase MCP `apply_migration`. Verify per `quickstart.md` Step 5: moderator has exactly 5 rows with the expected keys; admin has 16 rows; super_admin has 24 rows; `user`, `owner`, `agent`, `agency_admin` each have 0 rows. Run `get_advisors` — no new warnings expected.

### Backend SQL — `user_roles` table + audit trigger + auto-user-role trigger (R-01, R-14, R-15, FR-007, FR-010, FR-013)

- [X] T013 [P] Author `supabase/policies/user_roles_policies.sql` with two SELECT policies: `user_roles_self_read` (`auth.uid() = user_id`) and `user_roles_admin_cross_read` (`current_user_has_permission('users.view')`). Wrapped idempotently. No write policies (Phase 7 brings them; the backfill migration runs as `postgres` and bypasses RLS).
- [X] T014 Author `supabase/migrations/20260515120004_create_user_roles.sql` containing: the `user_roles` table per `data-model.md` "user_roles" schema (UUID PK, UNIQUE(user_id, role_id), FK posture per the contract); `ENABLE RLS`; the bundled policy bodies from `supabase/policies/user_roles_policies.sql`; the `auto_create_user_role_for_user()` SECURITY DEFINER function + `trg_profiles_auto_user_role` trigger on `AFTER INSERT ON profiles` per `contracts/auto-user-role-trigger.md`; **two separate audit triggers per Phase 5 convention** (Phase 4's `log_audit` takes the action string verbatim from `TG_ARGV[0]` — see `supabase/migrations/20260506120004_create_audit_logs.sql:24` — and does NOT append a TG_OP-derived verb): `DROP TRIGGER IF EXISTS trg_user_roles_audit_granted ON public.user_roles; CREATE TRIGGER trg_user_roles_audit_granted AFTER INSERT ON public.user_roles FOR EACH ROW EXECUTE FUNCTION log_audit('user_role.granted', '*', 'user_id');` AND `DROP TRIGGER IF EXISTS trg_user_roles_audit_revoked ON public.user_roles; CREATE TRIGGER trg_user_roles_audit_revoked AFTER DELETE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION log_audit('user_role.revoked', '*', 'user_id');` — no UPDATE trigger in v1 per R-15.
- [X] T015 Apply `20260515120004_create_user_roles.sql` via Supabase MCP `apply_migration`. Verify: `to_regclass('public.user_roles')` non-NULL; `pg_trigger` shows three triggers — `trg_profiles_auto_user_role`, `trg_user_roles_audit_granted`, and `trg_user_roles_audit_revoked`; the function `auto_create_user_role_for_user` exists. Run `get_advisors` — note `auto_create_user_role_for_user` is SECURITY DEFINER without explicit `search_path` qualifier on the function definition (verify the actual definition: `data-model.md` shows `SET search_path = public, auth` in the function body — confirm the migration's CREATE FUNCTION includes it; if not, the advisor flags it for hardening in T029).

### Backend SQL — `current_user_has_permission(perm_key)` helper (R-01, FR-008)

- [X] T016 Author `supabase/migrations/20260515120005_create_permission_predicate.sql`: a single `CREATE OR REPLACE FUNCTION public.current_user_has_permission(perm_key TEXT) RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth AS $$ … $$;` with the body per `contracts/permission-predicate.md` (the EXISTS-with-COALESCE wrapping over the three-way join `user_roles → role_permissions → permissions`).
- [X] T017 Apply `20260515120005_create_permission_predicate.sql` via Supabase MCP `apply_migration`. Verify: `pg_get_functiondef('public.current_user_has_permission(TEXT)'::regprocedure)` returns the expected body; from a privileged session, `SELECT current_user_has_permission('users.approve')` returns FALSE (no `auth.uid()`) without raising. Run `get_advisors` — `current_user_has_permission` may surface `function_anon_executable` (resolved by migration 8 T029).

### Backend SQL — `current_user_is_admin()` body swap (R-12, FR-012)

- [X] T018 Author `supabase/migrations/20260515120006_swap_admin_predicate_to_role_check.sql` with two responsibilities (both depend on `current_user_has_permission` from migration 5, so they land together): (1) the `CREATE OR REPLACE FUNCTION public.current_user_is_admin() RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth AS $$ SELECT COALESCE((EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = auth.uid() AND r.key IN ('admin', 'super_admin'))), FALSE) $$;` body swap; (2) the stacked cross-user `profiles` read policy bundled inline from `supabase/policies/profiles_phase6_users_view.sql` (T020 authors that policy file; T018's migration body appends the file's `DROP POLICY IF EXISTS … CREATE POLICY …` block, with a `-- generated from supabase/policies/profiles_phase6_users_view.sql` header comment per Phase 4's R-02 convention). **NO OTHER FILE IS EDITED IN THIS MIGRATION** — Phase 4 R-05 / Phase 5 R-12 central-helper invariant preserved a second time; the bundled policy is on `profiles` but lives in a NEW policy file (not edited into Phase 4's `profiles_policies.sql`). Migration body = the body swap + the bundled policy block + header comments naming the two contracts.
- [X] T019 Apply `20260515120006_swap_admin_predicate_to_role_check.sql` via Supabase MCP `apply_migration`. Verify: (a) `pg_get_functiondef('public.current_user_is_admin()'::regprocedure)` returns the role-membership body (contains `user_roles ur JOIN public.roles r` and `r.key IN ('admin', 'super_admin')`; does NOT contain `is_admin FROM profiles`); (b) `pg_policies` shows `profiles_phase6_users_view` on `public.profiles` alongside the existing Phase 4 / Phase 5 policies (`profiles_self_read`, `profiles_admin_read`, etc.). Run `get_advisors` — the search_path warning surfaced by Phase 5's swap is now resolved (the new body includes `SET search_path`); a new advisor warning may flag `current_user_is_admin` as anon-executable (resolved by migration 8 T023).

**⚠ HAZARDOUS INTERMEDIATE STATE**: at this checkpoint, `current_user_is_admin()` resolves to FALSE for every user (the `admin` role exists in the catalog but no `user_roles` rows assign it to anyone yet — the backfill in T037 fills that gap). Until T037 completes:
- Phase 5's admin queue page returns zero rows for the previously-admin user.
- The `enforce_profile_status_admin_only()` trigger fails-closed (gates non-admin mutations of `account_status`/`publisher_status` correctly — but a privileged session that tried to use the trigger for admin mutations would also be blocked; the trigger only allows mutations through `current_user_is_admin()` or `service_role`).
- Any in-app admin action attempted in this window will fail silently or with `42501`.

**CRITICAL**: Do NOT pause between T019 (this task) and T037. Land migrations 6, 7, 8 in one continuous apply batch. If a deploy is interrupted between them, restart the deploy from T036 immediately. **Do not leave the project in this intermediate state for any longer than the time it takes to apply the next two migrations** — typically under 60 seconds.

### Backend SQL — new cross-user `profiles` read policy (R-13, FR-009)

- [X] T020 Author `supabase/policies/profiles_phase6_users_view.sql` per `contracts/profiles-users-view-policy.md`: a single `CREATE POLICY profiles_phase6_users_view ON public.profiles FOR SELECT TO authenticated USING (public.current_user_has_permission('users.view'))` wrapped in `DROP POLICY IF EXISTS … CREATE POLICY …`. Phase 4's `supabase/policies/profiles_policies.sql` is NOT edited — the stacked policy lives in its own file. **R-05 invariant preserved.**
- [X] T021 Bundle the stacked policy file into the body-swap migration `20260515120006_swap_admin_predicate_to_role_check.sql` (T018) — append the file's contents at the end of the migration body, with a `-- generated from supabase/policies/profiles_phase6_users_view.sql` header comment matching Phase 4's R-02 inline-policy-bundling convention. This makes the policy's apply atomic with the migration tracker (one tracker row covers both the helper body swap and the stacked policy). **The migration filename does NOT change** — it stays at `20260515120006_swap_admin_predicate_to_role_check.sql`; only the body grows. Verification after the migration applies (still under T019): `pg_policies` shows `profiles_phase6_users_view` on `public.profiles` alongside the existing Phase 4 / Phase 5 policies (`profiles_self_read`, `profiles_admin_read`, etc.). **DO NOT** invoke `execute_sql` separately for this policy — the bundled migration is the canonical apply path.

### Backend SQL — Phase 6 advisor hardening (R-01 addendum, defense-in-depth)

- [X] T022 Author `supabase/migrations/20260515120008_phase6_advisor_hardening.sql`. Two responsibilities (parallel to Phase 5's `20260510120006_phase5_advisor_hardening.sql`): (1) `REVOKE EXECUTE … FROM PUBLIC, anon` on the three Phase 6 SECURITY DEFINER functions — `current_user_has_permission(TEXT)`, `current_user_is_admin()`, `auto_create_user_role_for_user()`; (2) explicit `GRANT EXECUTE … TO authenticated` on the two user-callable helpers (`current_user_has_permission`, `current_user_is_admin`). `auto_create_user_role_for_user` is trigger-only — no explicit GRANT to authenticated (it must be callable from the trigger context regardless, which doesn't need a GRANT since SECURITY DEFINER runs as the owner). Optionally also re-apply `SET search_path = public, auth` on `enforce_role_system_immutability()` if T006's get_advisors run flagged it.
- [X] T023 Apply `20260515120008_phase6_advisor_hardening.sql` via Supabase MCP `apply_migration`. Run `get_advisors` and confirm zero NEW security warnings beyond the Phase 4 + Phase 5 baseline. Document any remaining warnings in `specs/006-roles-permissions/HANDOFF.md` (or appended to `quickstart.md` Step 2's checklist).

### Backend documentation (FR-022)

- [X] T024 [P] Author `supabase/docs/roles.md`: purpose, columns + types + defaults, lifecycle (insert via seed; update of `display_name`/`description` allowed via Phase 7's UI; `key` rename + DELETE blocked for `is_system=TRUE` rows), RLS posture summary table, the system-role-immutability trigger reference, the seeded seven rows with their bilingual `display_name`. Cross-link to `contracts/roles-table.md` and `contracts/system-role-immutability-trigger.md`.
- [X] T025 [P] Author `supabase/docs/permissions.md`: purpose, columns, immutability (no UPDATE/DELETE in v1), RLS posture (authenticated-read), the seeded 24 keys per §9.1 grouped by category, the category breakdown. Cross-link to `contracts/permissions-table.md`.
- [X] T026 [P] Author `supabase/docs/role_permissions.md`: purpose, columns, PK, RLS posture, the seeded §9.1 default mappings (moderator 5 rows, admin 16 rows including the R-04 deltas, super_admin all 24), the FK posture (CASCADE / RESTRICT rationale). Cross-link to `contracts/role-permissions-table.md`.
- [X] T027 [P] Author `supabase/docs/user_roles.md`: purpose, columns, UNIQUE(user_id, role_id), RLS posture (self-read + users.view cross-read), the audit trigger reference, the auto-user-role trigger reference, the relationship to `profiles.account_status`. Cross-link to `contracts/user-roles-table.md`, `contracts/auto-user-role-trigger.md`, `contracts/user-roles-audit-trigger.md`.
- [X] T028 [P] Update `supabase/docs/audit_logs.md`: append a one-paragraph note that `log_audit()` is now also attached to `user_roles` via Phase 6's `20260515120004` migration, through TWO separate triggers — `trg_user_roles_audit_granted` (AFTER INSERT, action key `user_role.granted`) and `trg_user_roles_audit_revoked` (AFTER DELETE, action key `user_role.revoked`). No UPDATE trigger in v1. Note that the Phase 6 backfill (T037 — US2) emits many `user_role.granted` rows with `actor_user_id = NULL` (the migration runs as `postgres` with no `auth.uid()`); legitimate Phase 7+ assignments will have `actor_user_id = <super_admin uuid>`.

### Flutter core/security — abstract repository + impl (FR-014, R-09, R-10)

- [X] T029 [P] Create `lib/core/security/permission_catalog_repository.dart`: abstract `class PermissionCatalogRepository { Future<Set<String>> loadEffectivePermissions(); }` plus a `PermissionLoadFailure` sealed-class hierarchy (NetworkErrorPermission, NotAuthenticatedPermission, UnknownPermissionError). Constitution IX: NO `package:supabase_flutter` import. Pure domain shape.
- [X] T030 Create `lib/core/security/permission_catalog_repository_impl.dart` implementing `PermissionCatalogRepository`. Imports `package:supabase_flutter` (the only Phase 6 file in `lib/core/security/` that does). Uses `Supabase.instance.client` directly (the Phase 5 data-layer pattern — NO `SupabaseClientWrapper` constructor injection; the wrapper is not registered in get_it). Constructor takes no dependencies: `class PermissionCatalogRepositoryImpl implements PermissionCatalogRepository { PermissionCatalogRepositoryImpl(); … }`. Inside `loadEffectivePermissions()`, resolve `auth.uid()` via `Supabase.instance.client.auth.currentUser?.id` — if null, return an empty `Set<String>` (no permissions for an unauthenticated caller). Executes one Postgrest call per R-10: `final raw = await Supabase.instance.client.from('user_roles').select('role:roles(role_permissions(permission:permissions(key)))').eq('user_id', userId);` — returns `List<dynamic>` where each item is `{'role': {'role_permissions': [{'permission': {'key': '<key>'}}, …]}}`. Flatten to `Set<String>`:
  ```dart
  final keys = <String>{};
  for (final row in (raw as List)) {
    final rolePermissions = ((row as Map)['role'] as Map?)?['role_permissions'] as List? ?? const [];
    for (final rp in rolePermissions) {
      final key = ((rp as Map)['permission'] as Map?)?['key'] as String?;
      if (key != null) keys.add(key);
    }
  }
  return keys;
  ```
  Catch `PostgrestException` / network errors and rethrow as `PermissionLoadFailure` (NetworkErrorPermission / UnknownPermissionError) via the typed sealed hierarchy from T029. Depends on T029.

### Flutter core/security — PermissionChecker singleton + keys constants (FR-014, FR-018, R-08, R-19)

- [X] T031 [P] Create `lib/core/security/permission_keys.dart` per `contracts/permission-keys-dart.md`: `abstract class PermissionKeys { PermissionKeys._(); … }` with 24 `static const String` fields (camelCase of dot-namespaced key) + the derived `adminCategoryKeys` `Set<String>`. Constitution IX: pure Dart. No Supabase import.
- [X] T032 Create `lib/core/security/permission_checker.dart` per `contracts/permission-checker.md`: `class PermissionChecker { … }` with `load()`, `refresh()`, `has(String)`, `any(Iterable<String>)`, `all(Iterable<String>)`, `clear()`. Internal `Set<String> _cache` (initialized to empty const set); `bool _loaded`. On `refresh()` failure, retain previous `_cache`. Constructor takes a `PermissionCatalogRepository`. Constitution IX: imports the abstract repository + `dart:async` only. NO Supabase import. Depends on T029.

### Flutter DI registration (R-09)

- [X] T033 Register the new Phase 6 types with get_it. Phase 1 uses `injectable` + `build_runner` codegen — registrations live in `lib/core/di/injection.dart` (manual entries via `@module`/`registerSingleton`) and `lib/core/di/injection.config.dart` (auto-generated). The cleanest path: annotate `PermissionCatalogRepositoryImpl` with `@LazySingleton(as: PermissionCatalogRepository)` and `PermissionChecker` with `@lazySingleton` (the `injectable` annotations) so `build_runner` regenerates `injection.config.dart` to include `gh.lazySingleton<PermissionCatalogRepository>(() => PermissionCatalogRepositoryImpl())` and `gh.lazySingleton<PermissionChecker>(() => PermissionChecker(gh<PermissionCatalogRepository>()))`. **Run `flutter pub run build_runner build --delete-conflicting-outputs` after adding the annotations** so the codegen picks up. (If `PermissionCatalogRepositoryImpl` has no constructor dependencies — per T030 it uses `Supabase.instance.client` directly — the generated registration is a no-arg factory.) The lazy-singleton ensures the cache is built once per app lifetime and survives sign-out (the `clear()` method resets state but the instance is retained). Depends on T030, T032.

### Flutter ARB localization (Constitution V gate)

- [X] T034 Add ARB keys for the new admin home page and the profile-page Roles section to BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` in lockstep (Phase 3 lint gate fails any merge that adds a key to one file but not the other). Required keys:
  - `admin_home_title` (en: "Admin", ar: "الإدارة")
  - `admin_home_empty_title` (en: "No admin actions available", ar: "لا توجد إجراءات إدارية متاحة")
  - `admin_home_empty_body` (en: "Your role doesn't grant access to any admin features in this version.", ar: "صلاحياتك الحالية لا تمنحك الوصول إلى أي ميزات إدارية في هذا الإصدار.")
  - `profile_section_roles` (en: "Roles", ar: "الأدوار")
  - The `admin_tile_account_approvals` key already exists from Phase 5 (T039) — no change.
  Run the Phase 3 ARB lint gate (`flutter pub run …` per Phase 3's gate config) and confirm pass.

**Checkpoint**: Foundational phase complete. The remote project carries the 4 new tables with seeds + the helper + the body-swapped admin predicate + the cross-user profiles policy + the advisor hardening. The Flutter side has PermissionChecker + PermissionKeys wired via DI. ARB strings are in place. **But `current_user_is_admin()` still returns FALSE for every user** — the backfill in US2 (T036) is what restores the Phase 5 admin's role membership.

---

## Phase 3: User Story 1 - Seeded role and permission catalog goes live (Priority: P1)

**Goal**: Verify the seeded role/permission/role_permission catalog matches §9.1's intent (R-04 includes admin's two extra mappings beyond the literal 15-of-§9.1).

**Independent Test**: Per `quickstart.md` Steps 3–5: run the three verification SQL blocks and confirm the row counts and key sets match the expected values.

**Implementation**: Already complete via the foundational seed blocks (T005 / T008 / T011 / T014). US1's work is verification only.

- [ ] T035 [US1] Run the SC-001 / SC-002 / SC-003 verification per `quickstart.md` Steps 3, 4, 5. Specifically: confirm `SELECT count(*) FROM public.roles WHERE is_system = TRUE` returns 7; the seven keys match `[admin, agency_admin, agent, moderator, owner, super_admin, user]`; `display_name->>'ar'` and `display_name->>'en'` are populated for every system row; `SELECT count(*) FROM public.permissions` ≥ 24; the per-category counts match the expected breakdown; `moderator` has 5 mappings (`listings.approve, listings.reject, listings.view_all, reports.manage, users.view`); `admin` has 16 mappings (the R-04 list); `super_admin` has 24 mappings (all keys); `user`, `owner`, `agent`, `agency_admin` have 0 mappings each. Capture any unexpected counts in a follow-up task and adjust the seed migration before US2 starts.
- [ ] T035a [US1] Verify SC-008 — `current_user_has_permission` returns the right matrix across three user types — per `quickstart.md` Step 7's JWT-claims-simulation pattern. Pick three test users from the remote project: one regular `user`-only account, one prior-Phase-5 admin (post-T037 they'll hold `admin` role), and one moderator (you may need to INSERT a moderator-role row for a test user via `Supabase MCP execute_sql` if no moderator account exists). For each, run via Supabase MCP `execute_sql`:
  ```sql
  DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<test-user-uuid>","role":"authenticated"}', true); END $$;
  SET LOCAL ROLE authenticated;
  SELECT current_user_has_permission('users.approve');
  SELECT current_user_has_permission('users.view');
  SELECT current_user_has_permission('settings.manage');
  RESET ROLE;
  ```
  Expected: regular user → all three FALSE; moderator → `users.view` TRUE, others FALSE; admin → `users.approve` and `users.view` TRUE, `settings.manage` FALSE (super_admin only). **Note**: T035a runs AFTER US2's T037 (the backfill must have run so admin users hold the `admin` role). If T035a runs before T037, admin returns FALSE for all three. **SC-008 satisfied** when the matrix matches.
- [ ] T035b [US1] Verify SC-009 — moderator's new cross-user `profiles` read path works — per `quickstart.md` Step 9. JWT-claims-simulate a moderator and run `SELECT user_id, username FROM public.profiles WHERE user_id = '<another-existing-user-uuid>'` — expected: 1 row. Same query JWT-claims-simulated as a regular user → expected: 0 rows. **SC-009 satisfied**. Requires at least two test users on the remote project, one of them holding the moderator role.

**Checkpoint**: US1 verified — seeded catalog, helper matrix, cross-user read all confirmed. The foundation US2/US3/US4/US5 build on.

---

## Phase 4: User Story 2 - Interim `profiles.is_admin` is replaced cleanly (Priority: P1)

**Goal**: Apply the FR-011 backfill migration (admin role grants for prior admins + user role grants for every existing profile + column drop + trigger function rewrite) atomically. Restore the Phase 5 admin queue's "admin can approve" behavior. Remove the `Profile.isAdmin` Dart field. Rewire any Flutter call site that referenced `profile.isAdmin`.

**Independent Test**: Per `quickstart.md` Steps 6, 7, 13: every prior `is_admin=true` user holds the `admin` role; every existing profile holds the `user` role; the `is_admin` column is gone; `current_user_is_admin()` returns TRUE for the prior admins. Sign in on the device as the prior admin → admin tile visible → admin queue accessible → approve a pending registration → action succeeds + `audit_logs` row emitted.

### Backend — backfill + drop migration (R-11, FR-011)

- [ ] T036 [US2] Author `supabase/migrations/20260515120007_backfill_is_admin_and_drop.sql` per `contracts/is-admin-backfill-migration.md`. Five steps in order (the migration tool wraps in an implicit transaction): (a) `INSERT INTO public.user_roles … SELECT p.user_id, (SELECT id FROM public.roles WHERE key='admin'), NULL, now() FROM public.profiles p WHERE p.is_admin = TRUE ON CONFLICT DO NOTHING`; (b) `INSERT INTO public.user_roles … SELECT p.user_id, (SELECT id FROM public.roles WHERE key='user'), NULL, now() FROM public.profiles p ON CONFLICT DO NOTHING`; (c) `ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_admin`; (d) `CREATE OR REPLACE FUNCTION enforce_profile_status_admin_only()` with the body per `data-model.md` "Updated `enforce_profile_status_admin_only()`" — the `is_admin` reference is removed; the function continues to block non-privileged client mutations of `account_status` and `publisher_status`.
- [ ] T037 [US2] Apply `20260515120007_backfill_is_admin_and_drop.sql` via Supabase MCP `apply_migration`. **CRITICAL VERIFICATION** per `quickstart.md` Step 6:
  - SC-004: `SELECT count(DISTINCT ur.user_id) FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE r.key = 'admin'` returns ≥ **N_pre_admin** (from T001). Confirm every `user_id` in **L_admin_pre** (T001) appears in the post-migration query.
  - SC-005: `SELECT count(*) FROM public.profiles p WHERE NOT EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = p.user_id AND r.key = 'user')` returns 0.
  - SC-006: `SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='is_admin'` returns 0 rows. `SELECT is_admin FROM public.profiles LIMIT 1` errors with `42703 undefined_column`.
  - SC-015: `SELECT pg_get_functiondef('public.enforce_profile_status_admin_only()'::regprocedure)` does NOT mention `is_admin`.
  - **Audit count**: `SELECT count(*) FROM public.audit_logs WHERE action = 'user_role.granted' AND actor_user_id IS NULL` ≈ **N_pre_admin + M_profiles** (the backfill INSERTs fire the `trg_user_roles_audit_granted` trigger; the action key is `user_role.granted` per R-20, and `actor_user_id` is the column name per Phase 4's `audit_logs` schema — NOT `actor`).
  - Run `get_advisors` — confirm no new warnings.

### Frontend — Profile entity field removal + Phase 5 home-page admin-tile rewire (R-22)

- [ ] T038 [US2] Edit `lib/shared/domain/entities/profile.dart` to REMOVE the `final bool isAdmin` field. Update `copyWith` and `props` to drop the field. Verify no compile errors (Constitution IX: no Supabase imports affected). Depends on T037 — must follow the column drop so the entity matches the schema.
- [ ] T039 [US2] Edit `lib/features/profile/data/datasources/supabase_profile_datasource.dart` to remove `is_admin` from any `SELECT` column list and from any `update` map (the column no longer exists). The mapper from Supabase row → `Profile` entity drops the `isAdmin` field. Depends on T037, T038.
- [ ] T040 [US2] Edit `lib/features/home/presentation/pages/home_page.dart` to rewire the admin-tile visibility check from `profile.isAdmin` to `context.read<PermissionChecker>().any(PermissionKeys.adminCategoryKeys)`. The tile's `onTap` continues to navigate to `/admin/approvals` (the Phase 5 path); US4 (T046) changes the navigation target to `/admin` and rehosts the queue. **Shared-file warning**: T040 (US2) and T046 (US4) both edit `home_page.dart`; sequencing T040 before T046 keeps the diff clean. The admin-tile widget should be structured so US4's change is a one-line `onTap` update. Depends on T032 (PermissionChecker), T031 (PermissionKeys), T038 (entity field gone).
- [ ] T041 [US2] Edit `lib/core/routing/auth_redirect.dart` (the Phase 5 route-guard file — confirmed location; the file contains a `_redirectAuthenticated` helper that currently reads `profile.isAdmin`) to rewire the admin-route gating from `state.profile.isAdmin` to `getIt<PermissionChecker>().any(PermissionKeys.adminCategoryKeys)`. The redirect helper runs in the go_router redirect context, which is async-capable but the synchronous `PermissionChecker.any(...)` lookup is sufficient (the cache is populated by the auth-state listener BEFORE any route resolution against an authenticated session). Depends on T032, T033, T038.
- [ ] T042 [US2] Before any device walk, run from the repo root:
  ```bash
  grep -RnE 'profile\.isAdmin|isAdmin\s*[:=]|\bis_admin\b' lib/
  ```
  Expected: **zero matches**. If any match remains, the Phase 6 column drop will produce a runtime/compile error — find the missed call site, update it (most likely to use `PermissionChecker.any(...)`), and re-run the grep. Only after the grep returns clean, run `flutter analyze` and confirm zero errors.
  Then sign in on the reference Infinix Note 8 as the prior-Phase-5 admin user. Open the main navigation → confirm the "Admin" tile is visible (the `PermissionChecker` cache was populated on sign-in via the auth-state listener wired in US5 T054; **if US5 has not run yet**, you must complete US5 T054 + T055 BEFORE this verification, otherwise the cache is empty after sign-in and the admin tile stays hidden — see the "Dependencies & Execution Order" note about US5 sequencing). Tap the admin tile → land on the Phase 5 admin queue page (until US4 T051 + T052 ship, the tile navigates directly to the queue via `context.push(AppRoutes.adminApprovals)`). Approve one pending registration → confirm `account_approval_requests.status` flips to `approved`, `profiles.account_status` flips to `approved`, and `audit_logs` emits the Phase 5 audit row. **SC-007 satisfied.**

**Checkpoint**: US2 complete. The `is_admin` column is gone; the backfill restores admin role membership; Phase 5's admin queue continues to work; the Profile entity no longer carries the dropped field. Phase 6 has fundamentally replaced the interim Phase 5 stopgap.

---

## Phase 5: User Story 3 - User opens their profile and sees their assigned role(s) (Priority: P2)

**Goal**: Render a read-only "Roles" section on the profile page showing the localized display names for the signed-in user's `user_roles` assignments.

**Independent Test**: Per `quickstart.md` Step 15: sign in as a regular user, admin, and super_admin (if assigned post-deploy) — confirm the Roles section shows 1 / 2 / 3 entries respectively, in alphabetical order by `roles.key`, in the active locale's display name.

### Backend support (none needed beyond the foundational user_roles + roles tables)

### Frontend — domain entity + repository extension

- [ ] T043 [P] [US3] Create `lib/features/profile/domain/entities/assigned_role.dart`: `class AssignedRole extends Equatable { final String roleKey; final String displayName; final bool isSystem; … }`. Constitution IX: no Supabase imports. **Depends on nothing in Phase 6** — pure Dart class; can run in parallel with T044/T045/T046/T047 if developer capacity allows.
- [ ] T044 [US3] Extend `lib/features/profile/domain/repositories/profile_repository.dart` (the abstract from Phase 5) with a new method: `Future<List<AssignedRole>> loadAssignedRoles();`. Constitution IX: pure domain. Depends on T043.
- [ ] T045 [US3] Create `lib/features/profile/data/dtos/role_assignment_dto.dart` — Supabase-shape DTO for the `user_roles → roles` join. Maps the response row to `AssignedRole`, resolving `display_name->{active locale}` at the boundary (the active locale is read from the LocaleCubit at fetch time, with fallback per FR-017: active-locale value → other-locale value → `roles.key`). Imports `package:supabase_flutter` (data layer is the only Supabase boundary). Depends on T043.
- [ ] T046 [US3] Extend `lib/features/profile/data/datasources/supabase_profile_datasource.dart` with a new method: `Future<List<RoleAssignmentDto>> loadAssignedRoles(String userId)` that executes `supabase.from('user_roles').select('role:roles(key, display_name, is_system)').eq('user_id', userId)` and returns the list. Depends on T045.
- [ ] T047 [US3] Extend `lib/features/profile/data/repositories/profile_repository_impl.dart` to implement the new `loadAssignedRoles()` method: call the data source (T046), map each DTO to `AssignedRole`, sort by `roleKey` ascending (FR-017 deterministic order). Depends on T044, T045, T046.

### Frontend — presentation extension

- [ ] T048 [US3] Edit `lib/features/profile/presentation/pages/profile_page.dart` to add a new "Roles" section below the existing Phase 5 fields. The section renders:
  - A localized section header (ARB key `profile_section_roles` from T034).
  - A list of `AssignedRole.displayName` values for the signed-in user's roles, rendered as Phase 2 chip components (or whichever design-token component is appropriate for label lists).
  - No edit affordance — read-only (FR-017).
  The list is loaded via the existing Phase 5 ProfileCubit pattern: extend the cubit to also fetch `loadAssignedRoles()` alongside the existing profile load, emit a combined state. Constitution V: ARB strings only. Constitution VI: design tokens only. Depends on T047, T034.
- [ ] T049 [US3] Sign in on the reference device as each of: (a) a regular user, (b) the prior-Phase-5 admin (now holding `user` + `admin` roles), (c) (optional) a `super_admin` if T060 has assigned one. For each, open the profile page → scroll to the Roles section → verify the entry count and content per `quickstart.md` Step 15: regular = 1 entry ("User"/"مستخدم"), admin = 2 entries ("Admin", "User"/"مدير", "مستخدم" — alphabetical by key), super_admin = 3 entries. Toggle device locale Arabic ↔ English → confirm the display names flip. **SC-012 satisfied.**

**Checkpoint**: US3 complete. The profile page shows assigned roles read-only with locale-aware display names.

---

## Phase 6: User Story 4 - Admin-tile navigation visibility is permission-gated (Priority: P2)

**Goal**: Replace the Phase 5 single-tile admin surface with a tile-listing parent page (`AdminHomePage`) whose tiles render per-permission. Rehost the Phase 5 account-approvals page as a child of the new admin home.

**Independent Test**: Per `quickstart.md` Steps 13–14: sign in as regular user → no admin tile; sign in as admin → admin tile visible → tap → admin home page → "Account approvals" tile visible → tap → Phase 5 queue. Manually assign `moderator` role to a test user via Supabase MCP `execute_sql` → sign in → admin tile visible (any admin-category perm) but admin home shows empty-state copy because moderator doesn't hold `users.approve` (the queue tile requires it).

### Frontend — admin home page + route rehost

- [ ] T050 [US4] Create `lib/features/admin/presentation/pages/admin_home_page.dart`: a `Scaffold` whose `body` is a `ListView` (or `Column`) of admin tiles. Each tile is wrapped in a permission gate; the Phase 6 deliverable is one tile — "Account approvals" — gated by `context.read<PermissionChecker>().has(PermissionKeys.usersApprove)`. If no tiles match (e.g., a moderator opens the page), render the empty-state copy: a centered `Column` with the localized `admin_home_empty_title` (T034) as `Theme.of(context).textTheme.titleLarge` and `admin_home_empty_body` as `Theme.of(context).textTheme.bodyMedium`, separated by Phase 2 spacing tokens. Constitution V: every visible string from `AppLocalizations.of(context)`. Constitution VI: read every visual property from `Theme.of(context)` — no hardcoded hex/padding/font. If Phase 2's design-token module exposes a `ProjectListTile` (or similar named) wrapper, use it; otherwise use raw `ListTile` with `Theme.of(context).colorScheme.*` for any per-tile color. The tile's `onTap` calls `context.push(AppRoutes.adminApprovals)`. Use `context.watch<PermissionChecker>()` only if the cache must reactively rebuild on `refresh()`; `context.read<PermissionChecker>()` is sufficient if the page is dismissed and re-opened on permission changes (Phase 6's lifecycle-resume refresh path will rebuild the navigation tree from the home page, so a single `read` at page-build time is fine). Depends on T031, T032, T034.
- [ ] T051 [US4] Update `lib/core/routing/app_router.dart` to register `AdminHomePage` (T050) as the page widget for the EXISTING `/admin` parent route. The route constants are already in place from Phase 5 — verify by reading the file: `AppRoutes.admin = '/admin'` (line ~34) and `AppRoutes.adminApprovals = '/admin/approvals'` (line ~35) already exist, and the `/admin` route is registered as a parent with `/approvals` as a child (lines ~123–129). The Phase 5 implementation likely registered `/admin` with the queue page (or a placeholder) directly — Phase 6 reassigns it to `AdminHomePage` while the child `/admin/approvals` route continues to render the Phase 5 account-approvals page. **DO NOT** add or rename routes; the route paths are unchanged. The route guard from T041 (which gates `/admin` and `/admin/approvals` via `PermissionChecker.any(...)`) is unchanged. Depends on T050, T041.
- [ ] T052 [US4] Edit `lib/features/home/presentation/pages/home_page.dart` to change the admin tile's `onTap` from `context.push(AppRoutes.adminApprovals)` (the current Phase 5 target — verify by reading the file: line ~64 has `onTap: () => context.push(AppRoutes.adminApprovals)`) to `context.push(AppRoutes.admin)` (the new admin home tile-listing). Use `context.push` (NOT `context.go`) to match the Phase 5 navigation idiom — `push` adds to the navigation stack so the back button returns to home, which is the desired UX. Depends on T040 (US2 already rewired the visibility check from `profile.isAdmin` to `PermissionChecker.any(...)` — T052 only changes the navigation target on the `onTap` callback).
- [ ] T053 [US4] Sign in on the device as four distinct users (regular, moderator, admin, super_admin if available) and verify the SC-011 matrix per `quickstart.md` Step 14:
  - Regular user: no admin tile in the main navigation.
  - Moderator: admin tile visible; tapping it lands on `AdminHomePage`; the page shows the empty-state copy because moderator doesn't hold `users.approve`.
  - Admin: admin tile visible; tapping it lands on `AdminHomePage`; the "Account approvals" tile is visible; tapping it lands on `/admin/approvals` (the Phase 5 queue).
  - Super_admin: same as admin (super_admin also holds `users.approve` via the seeded mapping).
  **SC-011 satisfied.**

**Checkpoint**: US4 complete. The admin surface is now a permission-gated tile listing instead of a single fixed page. Phase 7's super-admin UI will add more tiles here (role management, user-role assignment) using the same pattern.

---

## Phase 7: User Story 5 - Permission cache stays current as the session lives (Priority: P3)

**Goal**: Wire the `PermissionChecker` cache lifecycle into the existing Phase 5 `AuthBloc` (which itself mixin-implements `WidgetsBindingObserver` — there is no separate observer file). Confirm the lifecycle entry points (the bloc's `_onSessionRefreshed` handler for the auth-state listener stream, and its `_onAppResumedRefresh` handler for foreground resume per R-21) all refresh the cache. No separate `refreshSession()` method exists on the bloc — Phase 5 uses an event-handled pattern with `SessionRefreshed` and `AppResumedRefresh` events.

**Independent Test**: Per `quickstart.md` Step 16: sign in as a regular user → admin tile hidden → background the app → INSERT an admin role assignment via Supabase MCP `execute_sql` → foreground the app → admin tile appears within ~1–3 seconds.

### Frontend — AuthBloc lifecycle hooks (FR-015, R-17)

- [ ] T054 [US5] Edit `lib/features/auth/presentation/bloc/auth_bloc.dart` (Phase 5's bloc — `class AuthBloc extends Bloc<AuthEvent, AuthState> with WidgetsBindingObserver`). Specifically:
  - **Constructor**: change the signature from `AuthBloc(this._authRepository, this._profileRepository)` to `AuthBloc(this._authRepository, this._profileRepository, this._permissionChecker)` (third positional arg). Add a matching `final PermissionChecker _permissionChecker;` field next to the existing two.
  - **`_onSessionRefreshed(SessionRefreshed event, Emitter<AuthState> emit)` handler** (already exists in the bloc — handles the auth-state listener stream): at the top of the handler, BEFORE computing the new state:
    - If `event.session != null` (the session is active): `await _permissionChecker.load();` — populates the cache before any UI rebuild reads from it.
    - If `event.session == null` (sign-out): `_permissionChecker.clear();`.
  - **`_onAppResumedRefresh(AppResumedRefresh event, Emitter<AuthState> emit)` handler** (already exists — handles foreground-resume per Phase 5 R-21): add `await _permissionChecker.refresh();` alongside the existing `ProfileRefreshed` dispatch. Order: refresh the permissions, THEN dispatch `ProfileRefreshed` (so a single rebuild after both complete shows the freshest state).
  - **Regenerate DI**: run `flutter pub run build_runner build --delete-conflicting-outputs` from the repo root. `lib/core/di/injection.config.dart` will pick up the new constructor argument automatically — the `gh.lazySingleton<AuthBloc>(...)` line gains a `gh<PermissionChecker>()` parameter. Verify by grepping the regenerated file for `AuthBloc(` and confirming three constructor args appear.
  - **DO NOT** create a separate `WidgetsBindingObserver` file in `lib/app.dart` or `lib/core/lifecycle/` — the observer is the bloc itself (mixin), already registered via `WidgetsBinding.instance.addObserver(this)` in the constructor.
  Depends on T032 (PermissionChecker created), T033 (PermissionChecker registered with get_it).
- [ ] T055 [US5] Verify the lifecycle wiring from T054 is complete by reading `lib/features/auth/presentation/bloc/auth_bloc.dart` and confirming:
  - The constructor has three positional parameters.
  - `_onSessionRefreshed` calls `_permissionChecker.load()` for non-null sessions and `_permissionChecker.clear()` for null sessions.
  - `_onAppResumedRefresh` calls `_permissionChecker.refresh()` before/around its `ProfileRefreshed` dispatch.
  - No new `WidgetsBindingObserver` file was created — the mixin on `AuthBloc` continues to be the single lifecycle observer.
  Run `flutter analyze` and confirm zero errors. Run `flutter test test/widgets/` (the existing Phase 1/2/3 tests) and confirm they still pass — the bloc constructor change MAY break tests that construct the bloc manually with two args; if so, update those test files to pass a `PermissionChecker` mock or a no-op fake as the third arg. Depends on T054.
- [ ] T056 [US5] On the reference device, exercise the foreground-resume refresh per `quickstart.md` Step 16:
  - Sign in as a regular user → confirm `PermissionChecker.has(PermissionKeys.usersApprove)` returns FALSE (no admin tile).
  - Background the app (press home, do not force-quit).
  - From a desktop via Supabase MCP `execute_sql`: `INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at) VALUES ('<this-user-uuid>', (SELECT id FROM public.roles WHERE key='admin'), NULL, now()) ON CONFLICT (user_id, role_id) DO NOTHING`.
  - Foreground the app on the device.
  - Within 1–3 seconds, confirm the admin tile appears in the main navigation.
  - Optional follow-on: tap the admin tile → admin home → "Account approvals" tile visible → tap → queue loads.
  **SC-010 satisfied.**

**Checkpoint**: US5 complete. The permission cache stays current via the three documented observation points without requiring Realtime (Phase 22 will revisit).

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Closure tasks for the Phase 6 PR — operational bootstrap, doc updates, drift checks, DEFERRED.md.

- [ ] T057 [P] Update `supabase/docs/profiles.md` to remove the `is_admin` column entry (the column is dropped). Append a section noting the new stacked cross-user read policy `profiles_phase6_users_view` gated by `users.view`; note that `current_user_is_admin()` now resolves to a role-membership check (admin or super_admin role). Cross-link to `contracts/admin-predicate-v6.md` and `contracts/profiles-users-view-policy.md`.
- [ ] T058 [P] Update `supabase/docs/account_approval_requests.md` (Phase 5's doc) to append a note: the admin-read / admin-update policies continue to gate on `current_user_is_admin()` whose body Phase 6 swapped to a role-membership check. The same set of users (prior Phase 5 admins, now holding the `admin` role) is admitted; Phase 5's behavior is unchanged.
- [ ] T059 Verify the no-Supabase-import invariant (SC-019) by running from the repo root:
  ```bash
  grep -R "package:supabase_flutter" lib/core/security/permission_checker.dart \
                                     lib/core/security/permission_keys.dart \
                                     lib/core/security/permission_catalog_repository.dart \
                                     lib/features/admin/domain/ \
                                     lib/features/profile/domain/
  ```
  Expected: zero output. (`permission_catalog_repository_impl.dart` IS allowed to import Supabase — verify it shows up in `grep "package:supabase_flutter" lib/core/security/permission_catalog_repository_impl.dart` with one match.)
- [ ] T060 Verify the no-Phase-4/5-policy-edit invariant (SC-016) by running from the repo root:
  ```bash
  git diff main..006-roles-permissions -- supabase/policies/profiles_policies.sql \
                                          supabase/policies/user_preferences_policies.sql \
                                          supabase/policies/audit_logs_policies.sql \
                                          supabase/policies/account_approval_requests_policies.sql
  ```
  Expected: zero output — none of the Phase 4 or Phase 5 policy files is edited. Confirm the new policy files DO appear via `git diff --name-only` on `supabase/policies/`.
- [ ] T060a Verify SC-013 — a non-admin user cannot INSERT into `user_roles` — per `quickstart.md` (add this as a verification step alongside the existing audit checks). JWT-claims-simulate a regular user via Supabase MCP `execute_sql`:
  ```sql
  DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<regular-user-uuid>","role":"authenticated"}', true); END $$;
  SET LOCAL ROLE authenticated;
  INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
  VALUES (auth.uid(), (SELECT id FROM public.roles WHERE key='admin'), NULL, now());
  -- Expected: ERROR — no INSERT policy admits this; the row insert is rejected by RLS with
  --   `new row violates row-level security policy for table "user_roles"`.
  RESET ROLE;
  ```
  **SC-013 satisfied.** Also confirm via `pg_policies` that no INSERT policy exists on `user_roles` (Phase 6 ships only SELECT policies; Phase 7 adds INSERT/DELETE policies).
- [ ] T061 Verify the no-hardcoded-role-check invariant (SC-020, FR-019) by grep'ing for forbidden patterns over the Phase 6-touched files:
  ```bash
  grep -RnE "role[s]?\\s*==\\s*['\"]\\w+['\"]|isAdmin\\s*==\\s*true" \
       lib/features/admin/ lib/features/profile/ lib/core/security/ lib/features/home/ lib/core/routing/
  ```
  Expected: zero matches. Permission gating is via `PermissionChecker.has(...)` exclusively.
- [ ] T062 [P] Run Supabase MCP `get_advisors` with `type: 'security'` against the remote project and document the final advisor state in `specs/006-roles-permissions/HANDOFF.md`. Expected: zero new warnings beyond the Phase 4 + Phase 5 baseline (any new warnings must be resolved before squash-merge).
- [ ] T063 [P] Re-apply each of the eight Phase 6 migrations via Supabase MCP `apply_migration` with the same names (SC-017 idempotency check). Confirm each apply succeeds, row counts in `roles` / `permissions` / `role_permissions` / `user_roles` are unchanged, the `is_admin` column stays dropped. The duplicate-tracker-row caveat (`project_supabase_mcp_apply_migration.md`) means the migration tracker gains a second row per migration — that's cosmetic, not a regression.
- [ ] T064 (OPERATIONAL — post-deploy) Bootstrap the first super_admin per R-16 / Q1 — Option C: run via Supabase MCP `execute_sql` as `postgres`:
  ```sql
  INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
  VALUES ('<chosen-super-admin-uuid>', (SELECT id FROM public.roles WHERE key = 'super_admin'), NULL, now())
  ON CONFLICT (user_id, role_id) DO NOTHING;
  ```
  Choose `<chosen-super-admin-uuid>` operationally (typically the project owner's user_id). Document the chosen user in the Phase 6 PR merge-commit message OR in a non-checked-in operational note. Verify: `SELECT count(DISTINCT ur.user_id) FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE r.key = 'super_admin'` returns 1. (Phase 7's super-admin UI requires this step to function on first deploy.)
- [ ] T065 Create `specs/006-roles-permissions/DEFERRED.md` per `project_deferred_work.md`. If no deferrals surfaced during implement (the typical case for a clean Phase 6), the file contains a single line: "No deferrals — Phase 6 ships complete." If any intentional gap surfaced (e.g., the lint guard from R-21 was decided to be deferred to a future spec), document the gap with the standard DEFERRED entry shape (Status / What works today / What's missing / Where the gap matters / How to close).
- [ ] T066 Final end-to-end manual walkthrough on the reference Infinix Note 8 per `quickstart.md` Step 12 / 18 / 20: cold app launch → sign in as the post-T064 super_admin → main navigation shows admin tile → tap → admin home → tap "Account approvals" → queue loads → approve a pending registration → SUCCESS → sign out → sign in as a regular user → main navigation does NOT show admin tile → profile page shows "User" role only. **SC-018 satisfied.**

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001 captures pre-migration counts before T036/T037 (US2) can verify the backfill.
- **Foundational (Phase 2)**: Depends on Setup. BLOCKS every user story phase. T006/T009/T012/T015/T017/T019/T023 must all complete before T035 (US1 verify) and T036 (US2 backfill).
- **US1 (Phase 3)**: Depends on Foundational. Verification-only — no implementation tasks beyond what Foundational shipped.
- **US2 (Phase 4)**: Depends on Foundational + T001 (baseline). The backfill (T036/T037) MUST complete before T042 (the device check that Phase 5's admin queue still works). T038/T039/T040/T041 (Flutter entity + Phase 5 home wire) MUST be in the same PR as T037 (the column drop), otherwise the Phase 5 home page references a deleted entity field.
- **US3 (Phase 5)**: Depends on Foundational. The `user_roles` and `roles` tables must exist (T015) and the `users.view` cross-read policy stack must be in place (T021) for the profile page's Roles section to render correctly for admin/moderator cross-user reads (though Phase 6's profile page only reads the SIGNED-IN user's roles, so the self-read policy alone is sufficient — the cross-user path is for Phase 7).
- **US4 (Phase 6)**: Depends on Foundational + US2 (the Phase 5 home admin-tile rewire in T040 happens in US2; US4's T052 just changes the tile's navigation target). The PermissionChecker (T032) and DI registration (T033) are foundational.
- **US5 (Phase 7)**: Depends on Foundational + US2 (the AuthBloc + lifecycle observer hooks need the PermissionChecker singleton from T032 + DI registration from T033; the entity field removal from T038 means the AuthBloc no longer reads `profile.isAdmin`). Strictly speaking, US5's T054 (AuthBloc wiring) is a prerequisite for US2's T042 verification (the device check that admin sees admin tile after sign-in), because without the auth-state listener wired to `PermissionChecker.load()`, the cache is empty after sign-in. **Recommendation**: do US5 T054/T055 BEFORE US2's T042 verification, even though the priority numbering is P1 for US2 and P3 for US5. The phase ordering is by priority of WHAT THE STORY DELIVERS; within the phase, intra-task dependencies may cross.

### User Story Dependencies (intra-Phase-6)

- **US1**: independent — pure verification.
- **US2**: independent at the SQL level — the backfill migration runs against the schema produced by Foundational. At the Flutter level, T038/T039/T040/T041 form one atomic commit with T037 (column drop) — separating them produces a broken intermediate state.
- **US3**: independent of US2 / US4 / US5 — the profile-page extension only consumes Foundational artifacts.
- **US4**: depends on US2 only for the home-page admin-tile change (T040 is in US2; T052 in US4 updates the navigation target).
- **US5**: depends on US2's T038 (entity field gone — AuthBloc no longer reads `profile.isAdmin`).

### Within Each User Story

- **US2**: T036 → T037 → (T038 ∥ T039 ∥ T040 ∥ T041) → T042.
- **US3**: (T043 ∥ T045) → T044 → T046 → T047 → T048 → T049.
- **US4**: T050 → T051 → T052 → T053.
- **US5**: T054 → T055 → T056.

### Parallel Opportunities

- **Phase 2 Foundational**: T004 / T007 / T010 / T013 (policy files) all in parallel. T024 / T025 / T026 / T027 / T028 (doc files) all in parallel. T029 (abstract repo) / T031 (permission keys) / T034 (ARB keys) in parallel — none depend on each other.
- **US3**: T043 / T045 in parallel (no inter-dependency).
- **Phase 8 Polish**: T057 / T058 (doc updates) in parallel; T059 / T060 / T061 (drift checks) in parallel; T062 / T063 (advisor + idempotency) in parallel.

---

## Parallel Example: Foundational Phase

```bash
# After the four create-table migrations apply (T006 / T009 / T012 / T015 — sequential because each depends on the prior),
# parallelize the doc files and Flutter scaffolding:

Task: "Author supabase/docs/roles.md (T024)"
Task: "Author supabase/docs/permissions.md (T025)"
Task: "Author supabase/docs/role_permissions.md (T026)"
Task: "Author supabase/docs/user_roles.md (T027)"
Task: "Update supabase/docs/audit_logs.md (T028)"
Task: "Create lib/core/security/permission_catalog_repository.dart (T029)"
Task: "Create lib/core/security/permission_keys.dart (T031)"
Task: "Add ARB keys (T034)"
```

---

## Implementation Strategy

### MVP First (Foundational + US2)

The MVP scope for Phase 6 is **Foundational + US2**:
1. Complete Phase 1: Setup (T001–T003).
2. Complete Phase 2: Foundational (T004–T034). The seeded catalog is the foundation; PermissionChecker / PermissionKeys / DI are in place.
3. Complete Phase 4: US2 (T036–T042). The backfill replaces the interim `is_admin` flag; Phase 5's admin queue continues to work.
4. **STOP and VALIDATE**: Run `quickstart.md` Steps 1–13 + Step 18. Verify SC-001 through SC-008 + SC-015 + SC-016 + SC-017. Phase 5's admin queue still works.
5. Deploy if needed (the squash-merge of the 006-roles-permissions branch).

The MVP delivery satisfies the Phase 6 contract from §Phase 6 of IMPLEMENTATION_PLAN.md: roles + permissions + role_permissions + user_roles tables; the catalog seeded; the `current_user_has_permission` helper; the `is_admin` column dropped; the body-swapped admin predicate; Phase 5's admin queue unbroken.

### Incremental Delivery

1. **Foundational + US2** → MVP (described above) → ship a milestone PR (still as the 006-roles-permissions branch).
2. **+ US3** → Profile page Roles section ships → ship as the same PR (no separate PR per Phase per `feedback_git_workflow.md`).
3. **+ US4** → AdminHomePage tile listing ships.
4. **+ US5** → Mid-session refresh wiring ships.
5. **+ Phase 8 Polish** → operational super_admin bootstrap (T064) + DEFERRED.md (T065) + final UI walkthrough (T066) → close PR → squash-merge.

Per `feedback_git_workflow.md`, the entire Phase 6 ships as ONE squash-merged PR to `main`, not per-story PRs. The story-by-story increments are internal checkpoints, not separate release artifacts.

### Parallel Team Strategy

With multiple developers (out of scope for the current solo-dev mode but documented for completeness):

1. Team completes Setup + Foundational together (~T001–T034).
2. Once Foundational is done:
   - Developer A: US2 (T036–T042) — owns the backfill atomicity.
   - Developer B: US3 (T043–T049) — independent.
   - Developer C: US4 (T050–T053) — depends on US2's home-page rewire.
   - Developer D: US5 (T054–T056) — depends on US2's entity field removal.
3. US3 / US4 / US5 land in sequence after US2 to avoid the home-page double-edit.

---

## Notes

- [P] tasks = different files, no inter-dependencies.
- [Story] label = which user story the task belongs to (US1, US2, US3, US4, US5).
- The 8 migrations are sequenced by 14-digit timestamp filename (T005 / T008 / T011 / T014 / T016 / T018 / T022 / T036). The body-swap migration (T018, the 6th) intentionally lands BEFORE the backfill migration (T036, the 7th) — verified in R-11.
- Manual UI verification on the reference Infinix Note 8 is the only acceptance signal for SC-007 / SC-010 / SC-011 / SC-012 / SC-018. The `flutter run --dart-define-from-file=.env.json` invocation is required per `project_dart_defines.md`.
- Spec-level `DEFERRED.md` review is the final gate before squash-merge per `project_deferred_work.md`.
- The Phase 22 follow-up tag for revisiting Realtime cache-refresh is captured in project memory `project_phase22_perm_cache_revisit.md` — surfacing on Phase 22 spec-creation.
- Squash-merge the Phase 6 PR per `feedback_git_workflow.md` once T066 passes.
