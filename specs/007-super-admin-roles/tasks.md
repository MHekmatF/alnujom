---

description: "Task list for Phase 7 — Super-Admin Role & Permission Management. Each task is self-contained with exact file paths and contract pointers so a cheaper LLM can implement without context-switching."
---

# Tasks: Super-Admin Role & Permission Management

**Input**: Design documents from `/specs/007-super-admin-roles/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/*.md`, `quickstart.md` — all complete and locked.

**Tests**: **NONE.** Per durable session feedback (`feedback_no_new_tests.md`), Phase 7 introduces ZERO new automated tests. Verification is manual SQL via Supabase MCP `execute_sql` + manual UI walks on the reference Infinix Note 8 device. Existing Phase 1–6 tests remain unchanged.

**Organization**: Tasks are grouped by user story. Each story's checkpoint is a self-contained increment that can be demo'd without subsequent stories.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel with other [P]-marked tasks in the same phase (different files, no dependency on incomplete tasks).
- **[Story]**: User story label (US1..US6). Setup / Foundational / Polish tasks have NO story label.
- Every task includes the exact absolute file path and a pointer to the relevant contract / data-model section.

## Path Conventions

- Repository root: `H:\alnujom-project\`
- Supabase artifacts: `H:\alnujom-project\supabase\`
- Flutter sources: `H:\alnujom-project\lib\`
- ARB files: `H:\alnujom-project\lib\l10n\`

## Implementer briefing (read once before T001)

Before starting, read:

1. `H:\alnujom-project\specs\007-super-admin-roles\spec.md` — entire file (especially the 6-bullet Clarifications section and the 27 Success Criteria).
2. `H:\alnujom-project\specs\007-super-admin-roles\plan.md` — entire file (especially the Project Structure tree which lists every file you will touch).
3. `H:\alnujom-project\specs\007-super-admin-roles\data-model.md` — entire file (RPC bodies, audit-trigger SQL, write-policy SQL, ARB key inventory).
4. `H:\alnujom-project\specs\007-super-admin-roles\quickstart.md` — only Steps 1, 2, and the cross-reference table at the end (you'll re-read individual steps when verification tasks reference them).
5. Skim the 9 contract files in `H:\alnujom-project\specs\007-super-admin-roles\contracts\` — these are the binding interface definitions.

The contract files contain canonical SQL bodies and Dart skeletons; the data-model contains the same with cross-references. When a task says "per `contracts/<X>.md` § Y", that section is your source of truth for the exact code/SQL.

---

## Phase 1: Setup

**Purpose**: Confirm environment + warm the toolchain. No code authored yet.

- [X] T001 Verify current git state: run `git status` and `git branch --show-current` from `H:\alnujom-project`. Expected output: branch `007-super-admin-roles`, working tree clean. If the branch is different, STOP and ask. If the tree is dirty, commit or stash before proceeding.

- [X] T002 [P] Verify Phase 6 is shipped on the remote Supabase project. Run via Supabase MCP `execute_sql` the four checks from `quickstart.md` § "Pre-flight" step 1: (a) `SELECT count(*) FROM public.roles WHERE is_system = true` returns `7`; (b) `SELECT count(*) FROM public.permissions` returns `24`; (c) `SELECT pg_get_functiondef('public.current_user_has_permission(text)'::regprocedure) IS NOT NULL` returns `true`; (d) `SELECT pg_get_functiondef('public.current_user_is_admin()'::regprocedure) LIKE '%user_roles%'` returns `true` (confirming Phase 6's body-swap is in place). If any check fails, STOP — Phase 7 cannot proceed without Phase 6.

- [X] T003 [P] Verify `H:\alnujom-project\.env.json` exists and contains valid Supabase credentials (URL + anon key + service_role key per project memory `project_dart_defines.md`). If missing, STOP and ask the user to provide the file. Do NOT commit `.env.json` (it is in `.gitignore`).

- [X] T004 Pre-record the chosen first super_admin `auth.users.id` (the project owner's UUID). Look it up via Supabase MCP `execute_sql`: `SELECT id, email FROM auth.users WHERE email = '<project-owner-email>'` — confirm exactly one row, capture the UUID as a literal string for use in T013. Store as a comment in `specs\007-super-admin-roles\quickstart.md` § Step 2 (replace `<chosen-uuid>` placeholder), but DO NOT commit the UUID to a migration file (R-03 invariant).

- [X] T005 [P] Pre-warm the Flutter toolchain. From `H:\alnujom-project`, run in order: `flutter clean`, `flutter pub get`. (Do NOT run `build_runner` yet — it runs after the new annotations land in T038 and T049; running it now would not regenerate the still-Phase-6 graph.)

- [X] T005a Capture pre-migration schema state to `H:\alnujom-project\specs\007-super-admin-roles\baseline-pre-migration.txt` (mirror of Phase 6's `specs/006-roles-permissions/baseline-pre-migration.txt`). Use Supabase MCP to gather: (a) `list_tables` output for `public` schema; (b) `list_migrations` output (the full ordered list); (c) `execute_sql` results for `SELECT pg_get_functiondef('public.current_user_is_admin()'::regprocedure)` and `SELECT pg_get_functiondef('public.current_user_has_permission(text)'::regprocedure)`; (d) `SELECT tgname FROM pg_trigger WHERE tgrelid IN ('public.roles'::regclass, 'public.role_permissions'::regclass, 'public.permissions'::regclass, 'public.user_roles'::regclass) AND NOT tgisinternal ORDER BY tgname`; (e) `SELECT tablename, policyname FROM pg_policies WHERE tablename IN ('roles', 'permissions', 'role_permissions', 'user_roles', 'profiles') ORDER BY tablename, policyname`. Concatenate the outputs verbatim with section headers in the file. This snapshot is the rollback reference if Phase 7 needs to be reverted.

**Checkpoint**: Environment confirmed, Phase 6 verified shipped, first-super_admin UUID identified, baseline snapshot captured.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Apply the 5 Phase 7 migrations + 3 new policy files + bootstrap the first super_admin. EVERY downstream user story depends on this phase.

**⚠️ CRITICAL**: No user story task may begin until Phase 2 is complete and verified.

- [X] T006 Author migration 1 file at `H:\alnujom-project\supabase\migrations\20260516120001_create_phase7_audit_triggers.sql`. Body: the full SQL from `specs\007-super-admin-roles\contracts\phase7-audit-triggers.md` § "Triggers" (all 8 `DROP TRIGGER IF EXISTS ... CREATE TRIGGER ...` blocks for `trg_roles_audit_created/updated/deleted`, `trg_role_permissions_audit_granted/revoked`, `trg_permissions_audit_created/updated/deleted`). Add a leading comment block citing FR-001/002/003 and the spec/contract source.

- [X] T007 Apply migration 1 via Supabase MCP `apply_migration` with name `20260516120001_create_phase7_audit_triggers` and body from T006. Then verify via Supabase MCP `execute_sql`: `SELECT tgname FROM pg_trigger WHERE tgrelid IN ('public.roles'::regclass, 'public.role_permissions'::regclass, 'public.permissions'::regclass) AND tgname LIKE 'trg_%audit%' ORDER BY tgname` returns the 8 expected trigger names.

- [X] T008 [P] Author `H:\alnujom-project\supabase\policies\roles_phase7_write.sql` with the SQL from `specs\007-super-admin-roles\contracts\phase7-write-policies.md` § "roles_phase7_write.sql" (the 3 `DROP POLICY IF EXISTS / CREATE POLICY` blocks for INSERT/UPDATE/DELETE gated by `current_user_has_permission('roles.create' | 'roles.update' | 'roles.delete')`).

- [X] T009 [P] Author `H:\alnujom-project\supabase\policies\role_permissions_phase7_write.sql` with the SQL from `contracts\phase7-write-policies.md` § "role_permissions_phase7_write.sql" (2 policy blocks for INSERT/DELETE gated by `permissions.manage`).

- [X] T010 [P] Author `H:\alnujom-project\supabase\policies\user_roles_phase7_write.sql` with the SQL from `contracts\phase7-write-policies.md` § "user_roles_phase7_write.sql" (2 policy blocks for INSERT/DELETE gated by `permissions.manage`).

- [X] T011 Author migration 2 file at `H:\alnujom-project\supabase\migrations\20260516120002_create_phase7_write_policies.sql`. Body: copy-paste the SQL from the three policy files T008/T009/T010 inline in this single migration (R-02 inline-bundling convention — the policy files are the source of truth; the inline copy is what actually applies). Add a leading comment block citing FR-004/005/006/007 and noting that the parallel `.sql` files exist for documentation.

- [X] T012 Apply migration 2 via Supabase MCP `apply_migration` name `20260516120002_create_phase7_write_policies` body from T011. Then verify via Supabase MCP `execute_sql`: `SELECT tablename, policyname, cmd FROM pg_policies WHERE policyname LIKE '%_phase7_%' ORDER BY tablename, policyname` returns the 7 expected policies (3 on `roles`, 2 on `role_permissions`, 2 on `user_roles`) per the table at the bottom of `contracts\phase7-write-policies.md` § Verification.

- [X] T013 Author migration 3 file at `H:\alnujom-project\supabase\migrations\20260516120003_create_mutate_role_rpc.sql`. Body: the full `CREATE OR REPLACE FUNCTION public.mutate_role(...)` block per `contracts\mutate-role-rpc.md` § "Body skeleton". The function MUST be `LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, auth`. Include the leading comment block citing FR-008 and the Clarifications Q3 / Q4 / Q5 decisions encoded in the body (optimistic-lock check raises 40001; super_admin permission-set immutability raises 42501; permission re-checks raise 42501; reserved role_key='super_admin' raises 23505).

- [X] T014 Apply migration 3 via Supabase MCP `apply_migration` name `20260516120003_create_mutate_role_rpc` body from T013. Then verify via Supabase MCP `execute_sql`: `SELECT pg_get_functiondef('public.mutate_role(text, uuid, text, jsonb, text, text[], timestamptz)'::regprocedure) IS NOT NULL` returns `true`.

- [X] T015 Author migration 4 file at `H:\alnujom-project\supabase\migrations\20260516120004_create_user_role_assignment_rpcs.sql`. Body: two `CREATE OR REPLACE FUNCTION` blocks — (a) `public.assign_role_to_user(target_user_id UUID, target_role_id UUID, confirmation_token TEXT) RETURNS JSONB` per `contracts\assign-role-to-user-rpc.md` § "Body skeleton"; (b) `public.revoke_role_from_user(target_user_id UUID, target_role_id UUID) RETURNS JSONB` per `contracts\revoke-role-from-user-rpc.md` § "Body skeleton". Both `LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, auth`. Include leading comment block citing FR-009 and the Q1/Q2 enforcement encoded in the bodies (two-step super_admin confirmation in assign; unconditional super_admin self-revoke block in revoke).

- [X] T016 Apply migration 4 via Supabase MCP `apply_migration` name `20260516120004_create_user_role_assignment_rpcs` body from T015. Then verify via Supabase MCP `execute_sql`: `SELECT count(*) FROM pg_proc WHERE proname IN ('assign_role_to_user', 'revoke_role_from_user')` returns `2`.

- [X] T017 Author migration 5 file at `H:\alnujom-project\supabase\migrations\20260516120005_phase7_advisor_hardening.sql`. Body per `contracts\mutate-role-rpc.md` § "RPC permission grant" + `assign-role-to-user-rpc.md` § "RPC permission grant" + `revoke-role-from-user-rpc.md` § "RPC permission grant" — six SQL statements total: `REVOKE EXECUTE ON FUNCTION public.mutate_role(TEXT, UUID, TEXT, JSONB, TEXT, TEXT[], TIMESTAMPTZ) FROM PUBLIC, anon;` and same shape for the other two functions; then `GRANT EXECUTE ... TO authenticated;` for all three. Include leading comment citing R-12 advisor-hardening pattern carry forward.

- [X] T018 Apply migration 5 via Supabase MCP `apply_migration` name `20260516120005_phase7_advisor_hardening` body from T017. Then run Supabase MCP `get_advisors` type=`security` and confirm the ONLY new entries are the three `authenticated_security_definer_function_executable` WARN-level lints for `public.mutate_role`, `public.assign_role_to_user`, `public.revoke_role_from_user`. These three WARNs are **expected and acceptable** — the Phase 7 RPCs MUST be `SECURITY DEFINER` per R-06 (so they can write through the RLS-gated catalog tables atomically), and they MUST be EXECUTE-able by the `authenticated` role (so super_admins can call them from the app). Defense-in-depth is enforced via the `current_user_has_permission('roles.create' | 'roles.update' | 'roles.delete' | 'permissions.manage')` re-checks at the top of each function body (T013 / T015). This is the same advisor pattern Phase 5 (`approve_account_approval_request`, `reject_account_approval_request`, `handle_new_auth_user`, the `app_vault_*` family) and Phase 6 (`current_user_has_permission`, `current_user_is_admin`, `auto_create_user_role_for_user`) already accept. **Failure condition**: if `get_advisors` returns ANY new lint OUTSIDE those three RPC entries (e.g., a `function_search_path_mutable`, a missing-RLS lint, a new public-execute on `anon`), STOP and investigate — those would indicate a regression in T013 / T015 / T017. The migration-5 advisor-hardening (`REVOKE EXECUTE ... FROM PUBLIC, anon; GRANT EXECUTE ... TO authenticated;`) is what neutralizes the stricter PUBLIC/anon advisory; it does not (and cannot) neutralize the by-design `authenticated_security_definer_function_executable` lint.

- [X] T019 Bootstrap the first super_admin per `quickstart.md` § Step 2. Run via Supabase MCP `execute_sql` (which runs as `postgres`): `INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at) SELECT '<UUID-from-T004>', id, NULL, now() FROM public.roles WHERE key = 'super_admin';`. Then verify: `SELECT count(*) FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE r.key = 'super_admin'` returns `1`, AND `SELECT action FROM public.audit_logs WHERE action = 'user_role.granted' AND target_id = '<UUID-from-T004>' ORDER BY created_at DESC LIMIT 1` returns one row (confirming the Phase 6 audit trigger fired via Phase 7's transaction path).

**Checkpoint**: All 5 migrations applied; all 7 write policies in place; first super_admin bootstrapped. The backend half of Phase 7 is shipped.

---

## Phase 3: User Story 6 — Audit Trail Coverage (Priority: P1)

**Goal**: Confirm every `roles` / `role_permissions` / `permissions` mutation produces the correct `audit_logs` row through the Phase 7 trigger groups. Phase 6's `user_roles` triggers continue to fire unchanged.

**Independent Test**: Run synthetic mutations via Supabase MCP `execute_sql` (as super_admin or as `postgres`) against the three tables and confirm the audit-log rows match the contract.

- [X] T020 [US6] Run the synthetic-mutation verification block from `quickstart.md` § Step 9c. Steps: (a) call `mutate_role(op:='create', role_key:='audit_test', display_name:='{"ar":"اختبار","en":"AuditTest"}'::jsonb, permission_keys:=ARRAY['users.view','reports.manage'], expected_updated_at:=NULL, role_id:=NULL, description:=NULL)` as super_admin (use JWT simulation pattern from quickstart Step 4d-i with the T004 UUID); (b) confirm via `SELECT action, count(*) FROM public.audit_logs WHERE created_at > now() - interval '30 seconds' GROUP BY action` returns `role.created=1, role_permission.granted=2`; (c) call `mutate_role(op:='delete', role_id:=<audit_test id>, expected_updated_at:=<current>, ...)`; (d) confirm post-delete audit shows `role.deleted=1, role_permission.revoked=2` (the cascade fired).

- [X] T021 [US6] Run the Phase 6 triggers preservation check from `quickstart.md` § Step 9a. Run via Supabase MCP `execute_sql`: `SELECT tgname FROM pg_trigger WHERE tgrelid = 'public.user_roles'::regclass AND NOT tgisinternal ORDER BY tgname`. Expected: `trg_user_roles_audit_granted`, `trg_user_roles_audit_revoked` are still present (Phase 6 triggers untouched, per FR-020 / SC-014). **ALSO verify FR-017** (`current_user_is_admin()` body unchanged): run `SELECT pg_get_functiondef('public.current_user_is_admin()'::regprocedure)` and confirm the returned body contains `'user_roles'` AND `'role_id'` AND the role keys `'admin'` AND `'super_admin'` (i.e., the Phase 6 role-membership check is preserved). The returned definition MUST be byte-identical to the value captured in T005a's baseline snapshot.

- [X] T022 [US6] Run the Phase 7 trigger counts check from `quickstart.md` § Step 9b. Expected: `roles` has 5 triggers (3 audit + Phase 6's `set_updated_at` + Phase 6's `enforce_role_system_immutability`), `role_permissions` has 2 audit triggers, `permissions` has 3 audit triggers.

- [X] T023 [US6] Run the system-row immutability check from `quickstart.md` § Step 9d: attempt `DELETE FROM public.roles WHERE key = 'admin'` and `UPDATE public.roles SET key = 'admin_renamed' WHERE key = 'admin'` via Supabase MCP `execute_sql`. Expected: both raise `42501` (the Phase 6 trigger continues to fire, per SC-017).

- [X] T023a [US6] **SC-018 idempotency check.** Re-apply each of the five Phase 7 migrations a second time via Supabase MCP `apply_migration` (same name, same body). Each apply MUST succeed without error. Then verify no duplicates created: (a) `SELECT tgname, count(*) FROM pg_trigger WHERE tgname LIKE 'trg_%audit%' AND tgrelid IN ('public.roles'::regclass, 'public.role_permissions'::regclass, 'public.permissions'::regclass) GROUP BY tgname HAVING count(*) > 1` returns 0 rows; (b) `SELECT policyname, count(*) FROM pg_policies WHERE policyname LIKE '%_phase7_%' GROUP BY policyname HAVING count(*) > 1` returns 0 rows; (c) `SELECT proname, count(*) FROM pg_proc WHERE proname IN ('mutate_role', 'assign_role_to_user', 'revoke_role_from_user') GROUP BY proname HAVING count(*) > 1` returns 0 rows (CREATE OR REPLACE FUNCTION replaces in-place); (d) `SELECT count(*) FROM supabase_migrations.schema_migrations WHERE name LIKE '20260516%'` — note: this MAY return a value > 5 because Supabase MCP `apply_migration` does NOT dedupe by name (project memory `project_supabase_mcp_apply_migration.md`). Duplicate tracker rows are acceptable AS LONG AS items (a) (b) (c) are zero — the SQL bodies are idempotent so the schema state is identical regardless of tracker-row count. Record SC-018 as verified.

**Checkpoint**: US6 verified independently. The audit trail covers every Phase 7 mutation surface; Phase 6 triggers continue to fire unchanged; migrations are confirmed idempotent. The backend is observably complete and safe before any UI ships.

---

## Phase 4: User Story 1 — Super-Admin Entry Tile + Route Guard (Priority: P1) 🎯 MVP

**Goal**: A super_admin sees a "Super-admin" tile on the Phase 6 `AdminHomePage`; tapping it opens a placeholder page (the actual `RolesListPage` ships in US2). Non-super_admin users do NOT see the tile and cannot deep-link to `/admin/super-admin/...`. Defense-in-depth: the RLS write policies and the RPC permission re-checks reject crafted writes from non-super_admins.

**Independent Test**: Build APK, install on device, sign in as 3 different account types (regular `user`, `admin`-only, the bootstrapped `super_admin`), confirm tile visibility matches FR-011, attempt deep-link `/admin/super-admin/roles` and confirm bounce for non-super_admin; verify defense-in-depth via Supabase MCP `execute_sql` with simulated non-super_admin JWT.

- [ ] T024 [US1] Extend `H:\alnujom-project\lib\core\security\permission_keys.dart`. **Pre-check**: use the `Grep` tool with pattern `adminCategoryKeys` and path `H:\alnujom-project\lib\core\security\permission_keys.dart` — if zero matches, STOP and report (Phase 6 didn't ship this file as expected; investigate before proceeding). Otherwise open the file and locate the `static const Set<String> adminCategoryKeys` declaration. Immediately after it, add per `contracts\super-admin-routing.md` § "Tile visibility" and `data-model.md` § 5.1:
  ```dart
  /// Phase 7: keys that gate the super-admin tile on AdminHomePage.
  /// Currently { rolesView, rolesCreate, rolesUpdate, rolesDelete, permissionsManage }.
  static const Set<String> superAdminCategoryKeys = <String>{
    rolesView, rolesCreate, rolesUpdate, rolesDelete, permissionsManage,
  };
  ```
  No other change to the file. Save.

- [ ] T025 [P] [US1] Add the `adminTileSuperAdmin` ARB key to `H:\alnujom-project\lib\l10n\app_ar.arb`. Find a logical insertion point (alphabetically near other `adminTile*` keys; if none, append before the closing `}`). Add:
  ```json
    "adminTileSuperAdmin": "الإدارة الفائقة",
    "@adminTileSuperAdmin": { "description": "Super-admin tile label on AdminHomePage (Phase 7)" },
  ```
  Then add the same key with English value `"Super-admin"` to `H:\alnujom-project\lib\l10n\app_en.arb`. Both files MUST be edited in lockstep (Phase 3 localization gate).

- [ ] T026 [US1] Update `H:\alnujom-project\lib\features\admin\presentation\pages\admin_home_page.dart`. **Pre-check**: `Read` the entire file first. Identify (a) the widget class used for existing tiles (likely `AdminHomeTile`, `ListTile`, or a project-specific wrapper) — capture the exact class name; (b) how `PermissionChecker` is accessed (via constructor injection? `context.read<PermissionChecker>()`? `getIt<PermissionChecker>()`?); (c) the existing tile's icon source (Material `Icons.X`, a design-token icon helper, etc.); (d) the existing tile's `onTap` handler style (`context.go(...)`, `context.push(...)`, etc.). Mirror those exact conventions for the new tile. Then append a new tile after the existing "Account approvals" tile, gated by `<checker-accessor>.any(PermissionKeys.superAdminCategoryKeys)`:
  ```dart
  // Conceptual shape — adapt to the exact accessor + widget class observed in the pre-check:
  if (<checker-accessor>.any(PermissionKeys.superAdminCategoryKeys)) {
    tiles.add(<TileWidgetClass>(
      icon: <icon-source>,           // e.g., Icons.shield or the equivalent design-token icon
      title: AppLocalizations.of(context)!.adminTileSuperAdmin,
      onTap: () => context.go('/admin/super-admin/roles'),  // or context.push if that's the project pattern
    ));
  }
  ```
  No inline TextStyle / Padding / Color literals. Save.

- [ ] T027 [US1] Extend the go_router config. Locate the existing `/admin` route in `H:\alnujom-project\lib\app.dart` (or wherever go_router is configured — search for `'/admin/approvals'`). Add four child routes per `contracts\super-admin-routing.md` § "Routes":
  - `/admin/super-admin/roles` — builder returns `const RolesListPage()` (TODO: this widget lands in US2; create a placeholder `class RolesListPage extends StatelessWidget { @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Roles list — coming in US2'))); }` in `lib\features\super_admin\presentation\pages\roles_list_page.dart` for now).
  - `/admin/super-admin/roles/:roleId` — placeholder `RoleEditorPage` (lands in US3).
  - `/admin/super-admin/roles/create` — placeholder `CreateRolePage` (lands in US4).
  - `/admin/super-admin/assign` — placeholder `AssignRolePage` (lands in US5).
  Each route has `redirect: _requireSuperAdmin`. The placeholders are temporary; later phases replace them.

- [ ] T028 [US1] Add the `_requireSuperAdmin` redirect helper. **Pre-check**: try to `Read` `H:\alnujom-project\lib\core\routing\auth_redirect.dart`. If the file exists, observe (a) how `PermissionChecker` is accessed in the existing redirect helpers (the DI accessor pattern — `getIt`, `Provider.of`, `context.read`, etc.); (b) the exact signature shape Phase 6 uses (some go_router redirects take `(BuildContext, GoRouterState)`, others take `(GoRouterState)` only; some return `FutureOr<String?>`). If the file does NOT exist, run `Grep` for `redirect:` across `H:\alnujom-project\lib\` to find where Phase 6's `/admin` route guard is configured — that file is where to add the new helper. Mirror Phase 6's signature shape and DI accessor exactly. Conceptual shape:
  ```dart
  // Adapt the parameter list + return type + DI accessor to match the existing Phase 6 redirect:
  <SignatureMatchingPhase6> _requireSuperAdmin(...) {
    final checker = <PermissionChecker-accessor>;  // exactly as Phase 6 does
    if (!checker.any(PermissionKeys.superAdminCategoryKeys)) {
      return '/admin';  // bounce to admin home (Phase 6 pattern)
    }
    return null;  // proceed
  }
  ```
  Export the helper if needed so T027 can import it.

- [ ] T029 [US1] Build the APK and install on the reference Infinix Note 8: from `H:\alnujom-project`, `flutter build apk --release --dart-define-from-file=.env.json`, then `adb install -r build\app\outputs\flutter-apk\app-release.apk`. (If `adb` is not in PATH, use the full Android SDK path or instruct the user to install manually.)

- [ ] T030 [US1] Walk `quickstart.md` § Step 4a + 4b + 4c on the device: sign in as a regular `user` → confirm admin tile hidden; deep-link `/admin/super-admin/roles` → bounced. Sign in as an `admin` (a Phase-6-backfilled admin) → confirm admin home opens but "Super-admin" tile is NOT visible. Sign in as the bootstrapped super_admin (T019 UUID) → confirm "Super-admin" tile IS visible → tap it → confirm the placeholder `RolesListPage` opens. Record observed behavior in a brief note (e.g., "Step 4a-4c: PASS").

- [ ] T031 [US1] Walk `quickstart.md` § Step 4d on a desktop via Supabase MCP `execute_sql` (defense-in-depth): simulate a non-super_admin JWT; attempt `mutate_role` create → confirm `42501`; attempt direct `INSERT INTO roles` → confirm `42501`. Record SC-012 / SC-013 as verified.

**Checkpoint**: US1 complete. A super_admin can navigate to the (placeholder) `RolesListPage`. Non-super_admins are blocked at three layers (UI hide, route guard, RLS+RPC). SC-001, SC-002, SC-012, SC-013 verified. This is the MVP slice — every later UI story builds on this scaffolding.

---

## Phase 5: User Story 2 — Roles List with System-Row Protection (Priority: P1)

**Goal**: `RolesListPage` shows the full role catalog from `public.roles`, alphabetical by `key`, with system rows badged and protected (no delete/rename affordance). Tapping a row navigates to `RoleEditorPage` (which is still a placeholder until US3).

**Independent Test**: Open `RolesListPage` as super_admin → confirm 7 system rows, each with `is_system` badge, alphabetical order, localized `display_name`. Long-press a system row → no delete affordance. Toggle locale → display names flip.

- [ ] T032 [P] [US2] Create domain entities in `H:\alnujom-project\lib\features\super_admin\domain\entities\`. Per `data-model.md` § 5.2.1 create three files: (a) `role_with_counts.dart` with fields `roleId, roleKey, displayName (Map<String,String>), description (String?), isSystem (bool), permissionCount (int), userCount (int), updatedAt (DateTime)`; (b) `role_detail.dart` with the same fields PLUS `permissionKeys (List<String>)`; (c) `permission_catalog_entry.dart` with `key, category, description? (String?)`. All extend `Equatable` and have `const` constructors. NO `package:supabase_flutter` imports (Constitution IX).

- [ ] T033 [P] [US2] Create the abstract repository at `H:\alnujom-project\lib\features\super_admin\domain\repositories\role_catalog_repository.dart` per `data-model.md` § 5.2.2. **ONLY** define these three method signatures in this task — the other methods land in later tasks and adding them now would create unused abstract surface:
  - `Future<List<RoleWithCounts>> listRoles();` — used by US2.
  - `Future<RoleDetail> loadRoleDetail(String roleId);` — used by US2 (when navigating to the editor).
  - `Future<List<PermissionCatalogEntry>> loadPermissionCatalog();` — used by US3's RoleEditorPage to render the checklist; declared here because it's a read method and belongs with the catalog repo.

  The other methods listed in `data-model.md` § 5.2.2 (`createRole`, `updateRole`, `deleteRole`, `loadAffectedUserCount`) ship later: `updateRole` in T047, `createRole` + `deleteRole` in T059, `loadAffectedUserCount` in T064. Do NOT add them in T033 — each follow-on task explicitly extends this abstract class. The data-model.md surface is the FINAL state after Phase 7 ships, not the T033-time state. NO Supabase imports in this file.

- [ ] T034 [P] [US2] Create DTOs in `H:\alnujom-project\lib\features\super_admin\data\dtos\`. Three files: (a) `role_dto.dart` matching `public.roles` columns (id UUID, key TEXT, display_name JSONB, description TEXT?, is_system BOOLEAN, created_at, updated_at) with `fromJson(Map<String,dynamic>)` and `toEntity()` factories; (b) `permission_dto.dart` matching `public.permissions` (id, key, category, description?); (c) `role_with_counts_dto.dart` carrying the role + the `permission_count` and `user_count` rollup numbers from the SELECT in T036.

- [ ] T035 [US2] Create `H:\alnujom-project\lib\features\super_admin\data\datasources\supabase_role_catalog_datasource.dart`. The class accepts a `SupabaseClient` (Phase 6's wrapper) via constructor. Implement two methods initially:
  - `Future<List<RoleWithCountsDto>> listRoles()` — direct Postgrest select (NO RPC exists for this; do NOT invent one):
    ```dart
    final response = await supabase
      .from('roles')
      .select('id, key, display_name, description, is_system, created_at, updated_at, role_permissions(count), user_roles(count)')
      .order('key');
    ```
    The Postgrest response shape: each row has `'role_permissions': [{'count': N}]` and `'user_roles': [{'count': M}]` (Postgrest returns the count as a single-element array of objects). Extract defensively — if the nested array is empty `[]`, treat the count as 0:
    ```dart
    final rolePermissionsArr = (row['role_permissions'] as List?) ?? const [];
    final permissionCount = rolePermissionsArr.isEmpty ? 0 : (rolePermissionsArr.first as Map)['count'] as int;
    final userRolesArr = (row['user_roles'] as List?) ?? const [];
    final userCount = userRolesArr.isEmpty ? 0 : (userRolesArr.first as Map)['count'] as int;
    ```
  - `Future<RoleDetailDto> loadRoleDetail(String roleId)` — direct Postgrest select:
    ```dart
    final response = await supabase
      .from('roles')
      .select('id, key, display_name, description, is_system, updated_at, role_permissions(permission:permissions(key))')
      .eq('id', roleId)
      .single();
    ```
    Flatten `response['role_permissions']` (a `List<Map>` where each map has a nested `'permission': {'key': '...'}`) to a `List<String>` of permission keys:
    ```dart
    final rpList = (response['role_permissions'] as List?) ?? const [];
    final permissionKeys = rpList
      .map((rp) => ((rp as Map)['permission'] as Map)['key'] as String)
      .toList();
    ```
  Annotate the class with `@LazySingleton(as: SupabaseRoleCatalogDataSource)` or follow the exact DI annotation pattern Phase 6 uses (Pre-check: `Grep` for `@LazySingleton` and `@injectable` across `H:\alnujom-project\lib\features\` to identify the convention).

- [ ] T036 [US2] Create `H:\alnujom-project\lib\features\super_admin\data\repositories\role_catalog_repository_impl.dart`. Annotated `@LazySingleton(as: RoleCatalogRepository)`. Constructor takes the `SupabaseRoleCatalogDataSource`. Implement `listRoles()` and `loadRoleDetail(String)` by delegating to the datasource and mapping DTOs to entities. Wrap Supabase errors (catch `PostgrestException`) in a domain `BackendFailure` exception class (create `lib\features\super_admin\domain\failures.dart` if not already present). NO `package:supabase_flutter` imports in the entity-conversion code.

- [ ] T037 [US2] Create use cases at `H:\alnujom-project\lib\features\super_admin\domain\usecases\list_roles.dart` and `load_role_detail.dart`. Each is a callable class (`class ListRoles { final RoleCatalogRepository _repo; ListRoles(this._repo); Future<List<RoleWithCounts>> call() => _repo.listRoles(); }`). Annotated `@injectable`.

- [ ] T038 [US2] Run `flutter pub run build_runner build --delete-conflicting-outputs` from `H:\alnujom-project`. This regenerates `lib\core\di\injection.config.dart` to register the new datasource, repository, and use cases. Confirm zero build errors. (Note: `@LazySingleton(as: ...)` annotations in T035–T037 + dependencies on `SupabaseClient` from Phase 6 are what build_runner picks up; if build fails, check that `@module`-style provider for `SupabaseClient` is already in place from Phase 6 — it should be.)

- [ ] T039 [P] [US2] Create `H:\alnujom-project\lib\features\super_admin\presentation\bloc\roles_list_bloc.dart`. Events: `LoadRoles`, `RefreshRoles`. States: `Initial`, `Loading`, `Loaded(List<RoleWithCounts>)`, `LoadFailure(Failure)`. Constructor injects `ListRoles` use case. `@injectable`. On `LoadRoles`: emit `Loading`, `await _listRoles()`, emit `Loaded` or `LoadFailure`. `RefreshRoles` is identical (pull-to-refresh). Use `flutter_bloc` patterns established in Phase 6's `AuthBloc`.

- [ ] T040 [P] [US2] Create `H:\alnujom-project\lib\features\super_admin\presentation\widgets\role_card.dart`. A `StatelessWidget` taking `RoleWithCounts role` and `VoidCallback onTap`. Renders: localized `displayName` per active locale (use `Localizations.localeOf(context).languageCode` to pick `ar` or `en`; fallback to `role.roleKey` if missing); `is_system` badge (a small chip) when `role.isSystem`; permission count + user count subtitle. Use Phase 2 design tokens from `lib\core\theme\` (Card, Chip, TextTheme); NO inline hex / TextStyle / padding values.

- [ ] T041 [US2] Replace the US1 placeholder at `H:\alnujom-project\lib\features\super_admin\presentation\pages\roles_list_page.dart` with the real implementation per `contracts\super-admin-routing.md` (implied) and `data-model.md` § 5.2.6. Use `BlocProvider<RolesListBloc>` seeding `LoadRoles()`. Body: `BlocBuilder` → `RefreshIndicator` → `ListView.builder` of `RoleCard` widgets (one per `RoleWithCounts`). Tile tap navigates `context.go('/admin/super-admin/roles/${role.roleId}')`. Add a `FloatingActionButton` for "Create" gated by `PermissionChecker.has(PermissionKeys.rolesCreate)` — the button taps `context.go('/admin/super-admin/roles/create')` (the create page is still a placeholder until US4; mark `// TODO(US4)` comment). The `AppBar.title` uses `AppLocalizations.of(context)!.superAdminRolesListTitle` (you will add this ARB key in Polish; for now a literal `'Roles'` string is acceptable as a temporary, but write `// TODO(Polish): ARB-localize` comment — better, add the ARB key now per the next task).

- [ ] T042 [US2] Add three new ARB keys to `H:\alnujom-project\lib\l10n\app_ar.arb` AND `app_en.arb` (lockstep): `superAdminRolesListTitle`, `roleBadgeSystem`, `rolePermissionsCount`. Use the EXACT plural shapes below (Arabic requires 6 plural forms per CLDR: zero, one, two, few, many, other; English uses 2):

  **`app_en.arb`** (English — 2 forms):
  ```json
  "superAdminRolesListTitle": "Roles",
  "@superAdminRolesListTitle": { "description": "Title of the super-admin roles list page" },
  "roleBadgeSystem": "System",
  "@roleBadgeSystem": { "description": "Badge label for is_system=true roles" },
  "rolePermissionsCount": "{count, plural, =0{No permissions} one{1 permission} other{{count} permissions}}",
  "@rolePermissionsCount": { "description": "Permission count summary on a role card", "placeholders": { "count": { "type": "int" } } }
  ```

  **`app_ar.arb`** (Arabic — 6 forms; literal Syrian-friendly Arabic, not Modern Standard Arabic where a natural Levantine equivalent exists):
  ```json
  "superAdminRolesListTitle": "الأدوار",
  "@superAdminRolesListTitle": { "description": "Title of the super-admin roles list page" },
  "roleBadgeSystem": "نظامي",
  "@roleBadgeSystem": { "description": "Badge label for is_system=true roles" },
  "rolePermissionsCount": "{count, plural, zero{لا صلاحيات} one{صلاحية واحدة} two{صلاحيتان} few{{count} صلاحيات} many{{count} صلاحية} other{{count} صلاحية}}",
  "@rolePermissionsCount": { "description": "Permission count summary on a role card", "placeholders": { "count": { "type": "int" } } }
  ```

  After saving, run `flutter gen-l10n` from `H:\alnujom-project` (the build typically auto-runs it; explicit invocation: `flutter gen-l10n`). Confirm the generated `AppLocalizations` class in `H:\alnujom-project\lib\l10n\app_localizations.dart` (or wherever Phase 3 configured the output) gains a `rolePermissionsCount(int count)` method.

- [ ] T043 [US2] Build APK + install: `flutter build apk --release --dart-define-from-file=.env.json && adb install -r build\app\outputs\flutter-apk\app-release.apk`.

- [ ] T044 [US2] Walk `quickstart.md` § Step 5 on the device: sign in as super_admin → open `RolesListPage` → confirm 7 rows, each with `is_system` badge, alphabetical order, localized names; toggle locale to English, confirm names flip; long-press a system row, confirm no delete affordance (US2 ships the read-only list — the create/delete affordances ship in US4). Record SC-003 as verified.

**Checkpoint**: US2 complete. The super_admin can see the role catalog. SC-003 verified.

---

## Phase 6: User Story 3 — Role Editor with Optimistic Locking + super_admin Protection (Priority: P1)

**Goal**: `RoleEditorPage` opens for a specific role; super_admin edits `display_name`, `description`, and permission set; Save dispatches `mutate_role` RPC atomically. Optimistic locking via `roles.updated_at` captured at open time. super_admin row's permission checklist rendered read-only.

**Independent Test**: Edit admin role → toggle a permission → save → confirm DB updated; force a 40001 via stale-token call → confirm UI shows reload prompt; open super_admin editor → confirm checklist read-only; force 42501 via direct RPC call with permission-set change → confirm error.

- [ ] T045 [US3] Extend `H:\alnujom-project\lib\features\super_admin\data\datasources\supabase_role_catalog_datasource.dart` (from T035) with three new methods: (a) `Future<List<PermissionDto>> loadPermissionCatalog()` → `supabase.from('permissions').select('id, key, category, description').order('category').order('key')`; (b) `Future<RoleMutationResponseDto> mutateRole(Map<String,dynamic> params)` → `supabase.rpc('mutate_role', params: params)`; the params map keys are `op`, `role_id`, `role_key`, `display_name`, `description`, `permission_keys`, `expected_updated_at` (use snake_case — Supabase passes through to PL/pgSQL named arguments).

- [ ] T046 [US3] Add a SQLSTATE→Failure mapping helper in `H:\alnujom-project\lib\features\super_admin\data\repositories\role_catalog_repository_impl.dart`. Per `research.md` § R-14 + `contracts\mutate-role-rpc.md` § "Error contract", create a private method `Failure _mapPostgrestException(PostgrestException e)` that switches on `e.code` (the SQLSTATE) AND the literal message text raised by the migration. **The substring matches MUST stay byte-identical to the `RAISE EXCEPTION '...'` strings in `20260516120003_create_mutate_role_rpc.sql` (T013); any change to one MUST be reflected in the other.** Author with a code comment at each branch citing the exact RAISE source line:

  ```dart
  Failure _mapPostgrestException(PostgrestException e) {
    final code = e.code ?? '';
    final msg = e.message;
    // 40001 — optimistic-lock conflict.
    // Source: 20260516120003_create_mutate_role_rpc.sql RAISE EXCEPTION 'role concurrent edit' USING ERRCODE = '40001'.
    if (code == '40001') return const RoleEditConflictFailure();
    // 42501 super_admin permission-set immutability.
    // Source: same migration RAISE EXCEPTION 'super_admin permission set is immutable' USING ERRCODE = '42501'.
    if (code == '42501' && msg.contains('super_admin permission set')) {
      return const SuperAdminPermissionsImmutableFailure();
    }
    // 42501 system-role immutability (Phase 6 trigger).
    // Source: 20260515120001_create_roles.sql RAISE EXCEPTION 'cannot delete system role' or 'cannot rename system role' USING ERRCODE = '42501'.
    if (code == '42501' && (msg.contains('system role') || msg.contains('cannot delete') || msg.contains('cannot rename'))) {
      return const SystemRoleImmutableFailure();
    }
    // 42501 generic permission-denied.
    if (code == '42501') return const RolePermissionDeniedFailure();
    // 23503 — FK ON DELETE RESTRICT (user_roles still references the role).
    if (code == '23503') return const RoleHasUsersFailure();
    // 23505 — UNIQUE(roles.key) or reserved 'super_admin' key.
    if (code == '23505') return const RoleKeyDuplicateFailure();
    // 22023 — invalid op argument (defensive).
    if (code == '22023') return const InvalidOpFailure();
    return BackendFailure(msg);
  }
  ```

  Create the corresponding `Failure` classes in `H:\alnujom-project\lib\features\super_admin\domain\failures.dart` (extending a common `Failure` base class — `Read` Phase 6's failures file or the project's `lib\core\errors\failures.dart` to match the existing base class pattern). All Failure classes should be `const` constructors. **Forward-extensibility note**: if a future spec refactors the migration to use `RAISE … USING ERRCODE='42501', DETAIL='super_admin_permissions_immutable'`, change the substring match to `e.details?.contains('super_admin_permissions_immutable') ?? false` in lockstep.

- [ ] T047 [US3] Implement `RoleCatalogRepository.mutateRole(...)` in `role_catalog_repository_impl.dart` per `data-model.md` § 5.2.2. Method signature:
  ```dart
  Future<RoleMutationResult> updateRole({
    required String roleId,
    Map<String, String>? displayName,
    String? description,
    List<String>? permissionKeys,
    required DateTime expectedUpdatedAt,
  });
  ```
  Body: construct the params map with `op: 'update'`, the supplied fields (NULLs preserved), pass `expected_updated_at` as ISO-8601 string (Supabase serializes); call `datasource.mutateRole(params)`; catch `PostgrestException` and rethrow via `_mapPostgrestException`; map the response DTO to `RoleMutationResult`. Also implement `loadPermissionCatalog()` by delegating.

- [ ] T048 [US3] Create `H:\alnujom-project\lib\features\super_admin\domain\entities\role_mutation_result.dart` (the response shape from `mutate_role`) per `data-model.md` § 5.2.1: fields `roleId, roleKey, displayName, description, permissionKeys, updatedAt`. Equatable. Create `MutateRoleParams` (sealed class or simple data class with `Create` and `Update` variants — Update variant carries `expectedUpdatedAt`). NO Supabase imports.

- [ ] T049 [US3] Create `H:\alnujom-project\lib\features\super_admin\domain\usecases\mutate_role.dart`. Single use case with `Future<RoleMutationResult> call(MutateRoleParams params)` that dispatches to the right repository method based on the params variant. Annotated `@injectable`.

- [ ] T050 [US3] Run `flutter pub run build_runner build --delete-conflicting-outputs` to register the new datasource methods, repository method, and use case.

- [ ] T051 [P] [US3] Add the 12 permission-category ARB keys to BOTH `H:\alnujom-project\lib\l10n\app_ar.arb` AND `app_en.arb` per `contracts\permission-category-localization.md` § "Inventory (12 keys)". Each key follows the pattern `permissionCategory<Capitalized>` (e.g., `permissionCategoryUsers`). Use the exact Arabic and English values from the inventory table. Add an `@<key>` description entry for each.

- [ ] T052 [P] [US3] Create `H:\alnujom-project\lib\features\super_admin\presentation\widgets\permission_category_header.dart` per `contracts\permission-category-localization.md` § "Widget implementation". The `_resolveLocalized` switch handles all 12 known categories; default fallback returns the raw `category` value. Consume Phase 2 typography token (`Theme.of(context).textTheme.titleMedium`).

- [ ] T053 [P] [US3] Create `H:\alnujom-project\lib\features\super_admin\presentation\widgets\permission_checklist.dart`. Props: `List<PermissionCatalogEntry> catalog`, `Set<String> selectedKeys`, `ValueChanged<String> onToggle`, `bool isReadOnly`. Body: group `catalog` by `category`; render a `PermissionCategoryHeader` per group; render a `Checkbox` row per permission with the localized `description` as the label; when `isReadOnly`, set `onChanged: null` on every checkbox AND prepend a banner reading `AppLocalizations.of(context)!.superAdminPermissionsLocked` (add this ARB key to both files in T060).

- [ ] T054 [US3] Create `H:\alnujom-project\lib\features\super_admin\presentation\bloc\role_editor_bloc.dart` per `contracts\role-editor-page.md` § "RoleEditorBloc". Events: `OpenRole(String roleId)`, `UpdateDisplayName(String locale, String value)`, `UpdateDescription(String value)`, `TogglePermission(String permKey)`, `Save`, `ReloadAfterConflict`, `Cancel`. States: `Initial`, `Loading`, `Editing(...)`, `SaveSucceeded`, `SaveConflict(reason)`, `LoadFailure(Failure)`. Constructor injects `LoadRoleDetail` + `MutateRole` use cases. Capture `expectedUpdatedAt` on `OpenRole`. On `TogglePermission`: ignore if `state.isSuperAdminRow == true` (defensive); else update the working `permissionKeys` set. On `Save`: construct `MutateRoleParams.Update(...)`, call `mutateRoleUseCase`, react to `RoleEditConflictFailure` → emit `SaveConflict('concurrent_edit')`; `SuperAdminPermissionsImmutableFailure` → `SaveConflict('super_admin_immutable')`; `SystemRoleImmutableFailure` → `SaveConflict('system_role_protected')`. Annotated `@injectable`.

- [ ] T055 [US3] Replace the US1 placeholder at `H:\alnujom-project\lib\features\super_admin\presentation\pages\role_editor_page.dart` with the real implementation per `contracts\role-editor-page.md` § "Page structure" and `data-model.md` § 5.2.6. Use `BlocProvider<RoleEditorBloc>` seeding `OpenRole(widget.roleId)`. Body: `BlocBuilder` → on `Editing` state, render `display_name.ar` TextField, `display_name.en` TextField, `description` TextField (multiline), then the `PermissionChecklist` widget with `isReadOnly: state.isSuperAdminRow`. `FloatingActionButton` for Save, disabled when `!state.dirty || state.saving`. On `SaveSucceeded` state, pop the page via `context.pop()`. On `SaveConflict(reason)` state, show a `SnackBar` with the appropriate localized ARB key per `contracts\role-editor-page.md` § "Error-to-localized-message mapping" — for `concurrent_edit` the SnackBar also offers a "Reload" action that dispatches `ReloadAfterConflict`. AppBar title uses `AppLocalizations.of(context)!.superAdminRoleEditorTitle` (add ARB key in T060).

- [ ] T056 [US3] Run `flutter pub run build_runner build --delete-conflicting-outputs` to pick up the new BLoC registration.

- [ ] T057 [US3] Build + install: `flutter build apk --release --dart-define-from-file=.env.json && adb install -r build\app\outputs\flutter-apk\app-release.apk`.

- [ ] T058 [US3] Walk `quickstart.md` § Step 6a + 6b + 6c on the device:
  - 6a: Open admin role editor → uncheck `ads.manage` → Save → confirm list reflects 16 permissions; verify audit log via Supabase MCP `execute_sql`.
  - 6b: Open super_admin row → confirm checklist read-only + banner visible; edit `display_name.en`, save → succeeds; force RPC rejection via Supabase MCP `execute_sql` per quickstart code block, confirm 42501.
  - 6c: Force optimistic-lock conflict: open admin role on device, run the Supabase MCP `execute_sql` block that bumps `updated_at`, attempt Save on device, confirm the localized conflict message + Reload action; tap Reload, confirm editor refreshes; then run the stale-token RPC call programmatically, confirm 40001.

  Record SC-004, SC-024, SC-025, SC-026 as verified.

**Checkpoint**: US3 complete. Role editing fully works including the optimistic-lock and super_admin-immutability guards. The most complex story in Phase 7 is shipped.

---

## Phase 7: User Story 4 — Custom Role Lifecycle (Priority: P2)

**Goal**: super_admin creates a custom role with selected permissions and deletes it (with the affected-users handling for non-empty role deletes).

**Independent Test**: Create `finance` role with `currencies.manage` only → confirm appears in list; create with duplicate key → rejected; delete empty role → succeeds; delete role with users assigned → confirmation dialog offers "revoke and delete" path.

- [ ] T059 [US4] Extend `H:\alnujom-project\lib\features\super_admin\data\repositories\role_catalog_repository_impl.dart` (from T036/T047) with two new methods:
  - `Future<RoleMutationResult> createRole(...)` — calls `mutateRole` RPC with `op: 'create'`, all fields supplied, `expected_updated_at: null`. Maps the response DTO.
  - `Future<void> deleteRole({required String roleId, required DateTime expectedUpdatedAt})` — calls `mutateRole` RPC with `op: 'delete'`, the `role_id`, `expected_updated_at`. Returns void on success.
  Map errors via `_mapPostgrestException` (T046). Also extend the abstract `RoleCatalogRepository` (T033) with these signatures.

- [ ] T060 [US4] Create `H:\alnujom-project\lib\features\super_admin\domain\usecases\delete_role.dart` (the create path flows through `MutateRole.call(MutateRoleParams.Create(...))` — no new use case needed). The `DeleteRole` use case takes `String roleId, DateTime expectedUpdatedAt`.

- [ ] T061 [US4] Run `flutter pub run build_runner build --delete-conflicting-outputs`.

- [ ] T062 [P] [US4] Create `H:\alnujom-project\lib\features\super_admin\presentation\widgets\confirmation_dialog.dart` per `research.md` § R-19. Reusable `showDialog`-style helper. Signature: `Future<bool?> showConfirmationDialog(BuildContext context, {required String title, required String body, required String confirmButtonLabel, required String cancelButtonLabel, bool destructive = false})`. Returns `Future<bool?>` (nullable) because Flutter's `showDialog<T>` returns `Future<T?>` — callers MUST treat a `null` return as cancel (e.g., `if (result == true) { ... }`, not `if (result) { ... }`). The cancel button calls `Navigator.pop(context, false)`; the confirm button calls `Navigator.pop(context, true)`. Uses Phase 2 design tokens (the AlertDialog primitive or whatever the project's `lib\core\widgets\` exposes for confirmation dialogs — `Read` `lib\core\widgets\` to find the existing primitive before building from scratch).

- [ ] T063 [US4] Create `H:\alnujom-project\lib\features\super_admin\presentation\pages\create_role_page.dart` per `data-model.md` § 5.2.6. A form with: TextField for `role_key` (with client-side validation: lowercase, no whitespace, NOT `super_admin`); TextField for `display_name.ar` and `display_name.en` (at least one required); TextField for `description`; the `PermissionChecklist` widget (NOT read-only — `isReadOnly: false`) seeded with empty `selectedKeys`. A Save button that dispatches `MutateRole(MutateRoleParams.Create(...))` directly via a small `CreateRoleBloc` (or use a stateful page + the use case directly — keep it simple). On success, pop. On `RoleKeyDuplicateFailure`, show inline error on the `role_key` field with `AppLocalizations.of(context)!.errorRoleKeyDuplicate`.

- [ ] T064 [US4] Extend `RolesListPage` (T041) with the delete affordance. **First**, add `Future<int> loadAffectedUserCount(String roleId)` to the abstract `RoleCatalogRepository` (`H:\alnujom-project\lib\features\super_admin\domain\repositories\role_catalog_repository.dart`, from T033) AND to the concrete `RoleCatalogRepositoryImpl` (T036). Implementation in the datasource (T035): `supabase.from('user_roles').select('id').eq('role_id', roleId).count(CountOption.exact)` — returns the count directly via `response.count`.

  **Then**, on long-press of a non-system row in `RolesListPage`: call `loadAffectedUserCount(roleId)` first; based on the count, open `ConfirmationDialog`:

  - **If `count == 0`**: dialog with title `AppLocalizations.of(context)!.confirmDeleteRoleTitle`, body `AppLocalizations.of(context)!.confirmDeleteRoleBody`, confirm button `AppLocalizations.of(context)!.actionDelete` (red/destructive), cancel button `actionCancel`. On confirm, dispatch `DeleteRole(roleId, expectedUpdatedAt)`.

  - **If `count > 0`** in Phase 7 v1 (before T082 lands): dialog with title `confirmDeleteRoleTitle`, body that interpolates the count via `AppLocalizations.of(context)!.errorRoleHasUsers(count)` (an ARB key with `{count}` placeholder — add it in T065). The dialog offers ONLY a "Cancel" / "Close" button — NO "Revoke and delete" affordance. The localized body text MUST direct the super_admin to revoke roles manually first via the Assign Roles page (US5 surface) before retrying delete. Once T082 lands in US5, this branch is REPLACED to add the "Revoke and delete" affordance — see T082 for the upgrade path. **Until T082 ships, do NOT expose any bulk-revoke action here** (avoids a half-functional UX in the Phase 4+US4-only MVP slice).

- [ ] T065 [P] [US4] Add the create + delete ARB keys to BOTH `H:\alnujom-project\lib\l10n\app_ar.arb` AND `app_en.arb`: `superAdminCreateRoleTitle`, `roleKeyLabel`, `roleDisplayNameLabelAr`, `roleDisplayNameLabelEn`, `roleDescriptionLabel`, `actionCreate`, `actionDelete`, `actionCancel`, `confirmDeleteRoleTitle`, `confirmDeleteRoleBody`, `confirmDeleteRoleBodyWithUsers`, `errorRoleKeyDuplicate`, `errorRoleHasUsers`. Use the natural Syrian-Arabic and English translations.

- [ ] T066 [US4] Build + install + walk `quickstart.md` § Step 7a + 7b + 7c + 7d on the device:
  - 7a: create the `finance` role; verify the row appears in list; verify SQL state via Supabase MCP `execute_sql`.
  - 7b: attempt duplicate-key creation; confirm rejection.
  - 7c: delete the empty `finance` role; verify cascade audit rows.
  - 7d: re-create `finance`, manually grant it to a test user via Supabase MCP `execute_sql`, attempt delete from the device, confirm the "1 user currently affected" dialog (in the Phase 7 first cut, just confirm the dialog appears with the explanatory message; the bulk-revoke-then-delete path is a US5 enhancement deferred to the polish phase).

  Record SC-005, SC-006, SC-007 as verified.

**Checkpoint**: US4 complete. Custom-role lifecycle works. Note: the bulk-revoke-then-delete path is intentionally rough until US5 ships the revoke RPC client-side wiring; this is acceptable per US4's P2 priority.

---

## Phase 8: User Story 5 — Assign / Revoke Roles with Mid-Session Propagation (Priority: P1)

**Goal**: super_admin searches for a user by phone or username, opens their role drawer, grants/revokes roles. Two-step confirmation for super_admin grants. Unconditional self-revoke block on the super_admin's own super_admin row. After grant, the affected user's app shows the new admin tile within seconds of foregrounding.

**Independent Test**: Search user, grant `moderator` → drawer refreshes; pick `super_admin` for a different user → two-step dialog opens, typed-match required; attempt self-revoke of own super_admin → no affordance + 42501 if forced via RPC; two-device test for mid-session propagation.

- [ ] T067 [P] [US5] Create domain entities at `H:\alnujom-project\lib\features\super_admin\domain\entities\`: (a) `user_search_result.dart` with `userId, phone, username, fullName, currentRoles (List<RoleAssignmentSummary>)`; (b) `role_assignment_summary.dart` with `roleId, roleKey, displayName, grantedAt`; (c) `role_assignment_result.dart` with `userId, roleId, grantedBy, at`. All Equatable. NO Supabase imports.

- [ ] T068 [P] [US5] Create the abstract repository at `H:\alnujom-project\lib\features\super_admin\domain\repositories\user_search_repository.dart` per `data-model.md` § 5.2.2: methods `searchUsers(String query)`, `loadUserAssignments(String userId)`, `assign({required String targetUserId, required String targetRoleId, String? confirmationToken})`, `revoke({required String targetUserId, required String targetRoleId})`.

- [ ] T069 [P] [US5] Create DTOs at `H:\alnujom-project\lib\features\super_admin\data\dtos\`: `user_search_result_dto.dart`, `assigned_role_dto.dart`, `assign_role_request_dto.dart`, `role_assignment_response_dto.dart`. Match the SELECT and RPC shapes from `contracts\assign-role-to-user-rpc.md` and `contracts\revoke-role-from-user-rpc.md`.

- [ ] T070 [US5] Create `H:\alnujom-project\lib\features\super_admin\data\datasources\supabase_user_search_datasource.dart` per `data-model.md` § 5.2.4 and `research.md` § R-13. Methods:

  - `searchUsers(String query)` — first SANITIZE the query string to prevent Postgrest filter-syntax injection. The `.or()` builder concatenates a literal filter expression; a `query` containing `,`, `;`, `(`, `)`, `=`, `:`, or `*` could break the expression. Strip these characters and reject empty results:
    ```dart
    Future<List<UserSearchResultDto>> searchUsers(String query) async {
      // Postgrest .or() filter sanitization. Reject reserved chars.
      final sanitized = query.replaceAll(RegExp(r'[,;()=:*]'), '').trim();
      if (sanitized.isEmpty) return const [];
      // Postgrest filter syntax: `column.op.value` joined by `,` inside or().
      // Both phone (prefix-match) and username (substring ILIKE).
      final response = await supabase
        .from('profiles')
        .select('user_id, phone, username, full_name')
        .or('phone.like.$sanitized%,username.ilike.%$sanitized%')
        .order('username')
        .limit(50);
      return (response as List).map((row) => UserSearchResultDto.fromJson(row as Map<String, dynamic>)).toList();
    }
    ```
    The cross-user read is admitted by Phase 6's `users.view`-gated policy because super_admin holds it. (Defense-in-depth: even if sanitization fails to catch a malicious payload, the Postgrest server will reject malformed filter syntax with a 400 error — Dart will surface as `PostgrestException`; the datasource maps to `BackendFailure`.)

  - `loadUserAssignments(String userId)` → `supabase.from('user_roles').select('role_id, granted_at, role:roles(id, key, display_name)').eq('user_id', userId)`. Flatten the nested `role` map into `AssignedRoleDto` fields.

  - `assign(...)` → `supabase.rpc('assign_role_to_user', params: {'target_user_id': targetUserId, 'target_role_id': targetRoleId, 'confirmation_token': confirmationToken})`. The `confirmationToken` is non-null only for super_admin grants.

  - `revoke(...)` → `supabase.rpc('revoke_role_from_user', params: {'target_user_id': targetUserId, 'target_role_id': targetRoleId})`.

  Annotate the class with `@LazySingleton(as: SupabaseUserSearchDataSource)` or the Phase 6 DI annotation convention identified in T035 pre-check.

- [ ] T071 [US5] Create `H:\alnujom-project\lib\features\super_admin\data\repositories\user_search_repository_impl.dart`. Annotated `@LazySingleton(as: UserSearchRepository)`. Delegate to the datasource; map DTOs to entities; catch `PostgrestException` and translate via a similar `_mapPostgrestException` (reuse the helper pattern from T046, or create a sibling). Per `research.md` § R-14: SQLSTATE 42501 with message containing `'super_admin grant confirmation'` → `SuperAdminGrantConfirmationFailedFailure`; 42501 with `'super_admin self-revoke'` → `SuperAdminSelfRevokeForbiddenFailure`; 42501 generic → `AssignPermissionDeniedFailure` or `RevokePermissionDeniedFailure` (whichever method was called); 23505 → `UserAlreadyHoldsRoleFailure`; 02000 → `UserDoesNotHoldRoleFailure`.

- [ ] T072 [US5] Create four use cases at `H:\alnujom-project\lib\features\super_admin\domain\usecases\`: `search_users.dart`, `load_user_assignments.dart`, `assign_role_to_user.dart`, `revoke_role_from_user.dart`. Each follows the pattern from T037 — single `call(...)` method delegating to the repository. Annotated `@injectable`.

- [ ] T073 [US5] Run `flutter pub run build_runner build --delete-conflicting-outputs`.

- [ ] T074 [P] [US5] Create `H:\alnujom-project\lib\features\super_admin\presentation\widgets\user_search_field.dart`. A `StatefulWidget` wrapping a debounced `TextField` (300ms per `research.md` § R-13). Props: `onChanged(String query)`. Use a `Timer` for the debounce; cancel on dispose.

- [ ] T075 [P] [US5] Create `H:\alnujom-project\lib\features\super_admin\presentation\widgets\assigned_role_row.dart`. Props: `RoleAssignmentSummary row`, `bool showRemoveAffordance`, `VoidCallback onRemove`. Renders the role's localized `display_name` + a remove icon button (shown only if `showRemoveAffordance == true`). Uses Phase 2 chip/list-item primitive.

- [ ] T076 [P] [US5] Create `H:\alnujom-project\lib\features\super_admin\presentation\widgets\super_admin_grant_confirmation_dialog.dart` per `contracts\assign-role-page.md` § "Two-step super_admin grant" and `research.md` § R-04. A two-page-flow widget: page A shows the consequences-acknowledgement text + an "I understand" button; page B (after acknowledgement) shows a TextField where the user types the target user's phone OR username, with an "Confirm grant" button enabled only when `typedValue == targetUser.phone || typedValue == targetUser.username`. On confirm, returns the `typedValue` to the caller. On cancel, returns null. Use `showDialog` or a multi-step modal — keep the implementation as simple as possible while preserving the two gates.

- [ ] T077 [US5] Create `H:\alnujom-project\lib\features\super_admin\presentation\bloc\assign_role_bloc.dart` per `contracts\assign-role-page.md` § "AssignRoleBloc". Events: `UpdateQuery(String)`, `SelectUser(String userId)`, `LoadAssignments(String userId)`, `GrantRole(String targetUserId, String targetRoleId)`, `GrantSuperAdminRole(String targetUserId, String targetRoleId, String confirmationToken)`, `RevokeRole(String targetUserId, String targetRoleId)`, `CloseDrawer`. States per the contract. On `GrantRole` where `targetRoleId` references super_admin: emit `GrantNeedsSuperAdminConfirmation(targetUser, targetRoleId)`; on `GrantSuperAdminRole`: dispatch `assignRoleToUserUseCase(targetUserId, targetRoleId, confirmationToken)`. On `RevokeRole`: dispatch `revokeRoleFromUserUseCase(targetUserId, targetRoleId)`. Reactive error mapping to `GrantFailed` / `RevokeFailed` states with the appropriate localized message per `contracts\assign-role-page.md` § "AssignRoleBloc Behavior outline".

- [ ] T078 [US5] Replace the US1 placeholder at `H:\alnujom-project\lib\features\super_admin\presentation\pages\assign_role_page.dart` with the real implementation per `contracts\assign-role-page.md` § "Page structure" and `data-model.md` § 5.2.6. **Pre-check the AuthBloc state shape**: `Read` `H:\alnujom-project\lib\features\auth\presentation\bloc\auth_bloc.dart` (Phase 5 file) and identify how the signed-in user's id is accessed. Phase 5 typically uses a sealed `AuthState` with an `Authenticated` subtype carrying a `Profile` or `Session` field. Capture the exact accessor chain (e.g., `(authBloc.state as Authenticated).profile.userId`, or `authBloc.state.session?.user.id`, or whatever the file shows). **All references below to `<self-user-id-accessor>` MUST be replaced with the exact accessor from the pre-check.**

  The page renders: `UserSearchField` (top), `ListView<UserSearchResult>` (middle, populated from `Results` state), and on `UserDrawerOpen` state, a `showModalBottomSheet` displays the user's `currentRoles` as `AssignedRoleRow` widgets + a "Grant role" `FloatingActionButton`. The remove affordance is suppressed for self-row super_admin per `_shouldShowRemoveAffordance`:

  ```dart
  bool _shouldShowRemoveAffordance(BuildContext context, RoleAssignmentSummary row, String selectedUserId) {
    // Phase 5 accessor — verify exact field path in pre-check before pasting:
    final selfUserId = <self-user-id-accessor>;
    final isSelfRow = selfUserId == selectedUserId;
    final isSuperAdminRole = row.roleKey == 'super_admin';
    return !(isSelfRow && isSuperAdminRole);  // hide for self super_admin (R-05 UI half)
  }
  ```

  On "Grant role" tap: open a role picker. The picker reads the roles list from `RolesListBloc` (provided to this page via `BlocProvider.value(value: getIt<RolesListBloc>())` — ensure the bloc is already loaded before opening the picker; if not, call `bloc.add(LoadRoles())` and `await` the `Loaded` state). Filter the picker list to exclude roles the user already holds. On pick, dispatch `AssignRoleBloc.GrantRole(targetUserId, targetRoleId)` event.

  The bloc's `GrantNeedsSuperAdminConfirmation` state listener opens `SuperAdminGrantConfirmationDialog` (T076); on dialog return (non-null typed value), dispatch `GrantSuperAdminRole(targetUserId, targetRoleId, typedValue)`.

  The remove affordance (when shown by `_shouldShowRemoveAffordance`) opens the standard `ConfirmationDialog` (T062); on confirm (true), dispatch `RevokeRole(targetUserId, targetRoleId)`.

  Localized strings: every visible label uses `AppLocalizations.of(context)!.<key>` per the ARB keys added in T080.

- [ ] T079 [US5] Run `flutter pub run build_runner build --delete-conflicting-outputs`.

- [ ] T080 [US5] Add the AssignRolePage ARB keys to BOTH ARB files: `superAdminAssignRoleTitle`, `userSearchPlaceholder`, `userSearchEmptyResults`, `actionGrant`, `actionRevoke`, `confirmGrantRoleTitle`, `confirmGrantRoleBody`, `confirmRevokeRoleTitle`, `confirmRevokeRoleBody`, `confirmSuperAdminGrantTitle`, `confirmSuperAdminGrantBody`, `confirmSuperAdminGrantAckButton`, `confirmSuperAdminGrantTypedMatchLabel`, `confirmSuperAdminGrantConfirmButton`, `errorSuperAdminGrantConfirmationFailed`, `errorAssignPermissionDenied`, `errorRevokePermissionDenied`, `errorSuperAdminSelfRevokeForbidden`, `errorUserAlreadyHoldsRole`, `errorUserDoesNotHoldRole`.

- [ ] T081 [US5] Build + install + walk `quickstart.md` § Step 8a + 8b + 8c + 8d + 8e + 8f on the device(s):
  - 8a: search by phone prefix, confirm results appear within ~1s.
  - 8b: grant `moderator` to a non-super-admin user; confirm drawer refreshes and SQL state matches.
  - 8c: pick `super_admin` for a different user; confirm `SuperAdminGrantConfirmationDialog` opens; type wrong value, confirm button disabled; type correct phone, confirm grant succeeds.
  - 8d: search self; confirm remove affordance on own super_admin row is NOT rendered; force RPC self-revoke via Supabase MCP, confirm 42501.
  - 8e: two-device test — second device signed in as user granted in 8b; background; foreground; confirm admin tile appears within seconds (SC-011 — the most operationally important success criterion of Phase 7).
  - 8f: revoke `moderator`; confirm tile disappears on second device after foreground.

  Record SC-008, SC-009, SC-010, SC-011 as verified.

- [ ] T082 [US5] (Cleanup pass — upgrades T064's `count > 0` branch.) Now that the revoke RPC is wired through `UserSearchRepository`, edit `RolesListPage`'s long-press delete handler (T064) to replace the "Cancel only" dialog branch with the proper "Revoke and delete" flow:

  - When the user long-presses a non-system role with `count > 0`: open a dialog with title `confirmDeleteRoleTitle`, body interpolating the count (use a new ARB key `confirmDeleteRoleBodyWithUsers(count)`), TWO buttons — "Revoke and delete" (destructive) and "Cancel".
  - On "Revoke and delete": (a) fetch the list of users holding the role via `supabase.from('user_roles').select('user_id').eq('role_id', roleId)`; (b) iterate and call `userSearchRepository.revoke(targetUserId: each.userId, targetRoleId: roleId)` sequentially — if ANY revoke fails (catches `Failure`), abort the loop, surface the localized error, and do NOT proceed to the delete; (c) once all N revokes succeed, call `roleCatalogRepository.deleteRole(roleId: roleId, expectedUpdatedAt: <fresh-value>)` — note: the `expected_updated_at` token must be re-captured AFTER the revokes because Phase 4's `set_updated_at` trigger fires on every `roles` UPDATE, including the cascade from `user_roles` revokes (though FK cascades don't actually UPDATE roles — the token captured at long-press time IS still valid; double-check via a fresh `SELECT updated_at FROM roles WHERE id = X` right before the delete call); (d) on success, refresh the list.

  Add the new ARB key `confirmDeleteRoleBodyWithUsers` to both ARB files with the appropriate plural shape (English: `{count, plural, one{This role is assigned to 1 user. Revoke and delete?} other{This role is assigned to {count} users. Revoke from all and delete?}}`; Arabic: 6 forms per CLDR; use natural Syrian-friendly Arabic).

**Checkpoint**: US5 complete. All four primary user stories (US1, US2, US3, US5) plus the secondary US4 are shipped. Phase 7's full UI surface is exercised.

---

## Phase 9: Polish & Cross-Cutting

**Purpose**: Documentation, lint passes, ARB completeness, and the final golden-path walk.

- [ ] T083 [P] Update `H:\alnujom-project\supabase\docs\roles.md`: append a section per `plan.md` § "Storage > Three updated doc files" noting the Phase 7 write-side RLS policies (with link to `supabase/policies/roles_phase7_write.sql`), the new audit-trigger group (`role.created` / `role.updated` / `role.deleted` action keys), and the `mutate_role` RPC as the canonical mutation surface.

- [ ] T084 [P] Update `H:\alnujom-project\supabase\docs\permissions.md`: append a section noting the new defensive audit-trigger group (`permission.created` / `.updated` / `.deleted`); reaffirm immutability in v1.

- [ ] T085 [P] Update `H:\alnujom-project\supabase\docs\role_permissions.md`: append a section noting the new write-side RLS policies + audit-trigger group + the `mutate_role` RPC computes the delta server-side.

- [ ] T086 [P] Update `H:\alnujom-project\supabase\docs\user_roles.md`: append a section noting the new write-side RLS policies; reaffirm Phase 6's `trg_user_roles_audit_*` triggers are unchanged; note the two new assignment RPCs as the canonical in-app mutation surface; note the two-step super_admin confirmation and the unconditional super_admin self-revoke block.

- [ ] T087 [P] Update `H:\alnujom-project\supabase\docs\audit_logs.md`: enumerate the seven new action keys from Phase 7 (`role.created`, `role.updated`, `role.deleted`, `role_permission.granted`, `role_permission.revoked`, `permission.created`, `permission.updated`, `permission.deleted`).

- [ ] T088 SC-019 — Constitution IX gate. Use the harness's `Grep` tool (NOT a shell `grep` — PowerShell does not ship `grep`) with pattern `package:supabase_flutter` and paths `H:\alnujom-project\lib\features\super_admin\domain` and `H:\alnujom-project\lib\core\security`. Run two separate Grep calls if needed (one per path). Expected: zero matches across both paths. If any match, fix by moving the Supabase reference into `lib\features\super_admin\data\datasources\` or `lib\features\super_admin\data\repositories\`. Document the result.

- [ ] T089 SC-020 — Constitution VII gate. Use the harness's `Grep` tool with pattern `user\.role\s*==\s*['"](super_admin|admin|moderator|user|owner|agent|agency_admin)['"]` and paths `H:\alnujom-project\lib\features\super_admin` and `H:\alnujom-project\lib\core\security`. Expected: zero matches. Then run a second `Grep` with pattern `PermissionChecker\.(has|any|all)` and the same paths, `output_mode: "count"`. Expected: > 0 matches (every gate consults the checker). If the count is zero, the page logic is broken — investigate.

- [ ] T090 SC-021 — ARB completeness (Phase 3 localization gate). Use the harness's `Grep` tool with pattern `permissionCategory` and `output_mode: "count"`, once on `H:\alnujom-project\lib\l10n\app_ar.arb` and once on `H:\alnujom-project\lib\l10n\app_en.arb`. Expected: 12 matches each (the 12 category keys defined in `contracts\permission-category-localization.md` § "Inventory (12 keys)"). If a count differs, audit the inventory and add the missing key(s). Also run a manual visual inspection of the device in both `ar` and `en` locales — `RolesListPage`, `RoleEditorPage`, `CreateRolePage`, `AssignRolePage` all render correctly in both directions.

- [ ] T091 SC-022 — Constitution VI gate. Use the harness's `Grep` tool with pattern `0x[fF][fF][0-9a-fA-F]{6}` and path `H:\alnujom-project\lib\features\super_admin`. Expected: zero matches (no inline hex color literals). Then `Grep` with pattern `TextStyle\(` and path `H:\alnujom-project\lib\features\super_admin\presentation`. Expected: zero matches (every text style comes from `Theme.of(context).textTheme.*`). If any match, replace with a token reference from `lib\core\theme\`.

- [ ] T092 Author `H:\alnujom-project\specs\007-super-admin-roles\DEFERRED.md`. **Important distinction**: known design-choice carve-outs (the Edge Function `mutate_role` path per R-06, Realtime cache refresh per R-17, bulk operations on AssignRolePage per R-20, the optional lint guard per R-21) are NOT deferrals — they are intentional v1 scope decisions already documented in `research.md` and `spec.md` Assumptions. Only document a deferral here if a Phase 7 implementation task could not be completed for an UNINTENDED reason (a blocking environment issue, a discovered constraint that couldn't be designed-around in this PR, etc.). Expected content for the normal case (matching Phase 6 pattern): the single line:

  ```
  No deferrals — Phase 7 ships complete.
  ```

  If a deferral exists, format each entry as a short paragraph: a one-line title, a "What's missing:" line, a "Why it's deferred:" line, and a "Tracking:" line (link to the future spec or issue that owns the follow-up). Save.

- [ ] T093 Run the full golden-path walk per `quickstart.md` § Step 11. Cover all 11 sub-steps end-to-end with the SQL verifications at the end. Record any failures and address them before claiming Phase 7 done.

**Checkpoint**: Phase 7 complete. Ready for squash-merge per `feedback_git_workflow.md`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup. Blocks all user-story phases.
- **US6 (Phase 3)**: Depends on Foundational. Can run in parallel with US1 backend-side verification.
- **US1 (Phase 4)**: Depends on Foundational. **MVP slice.** Tile + route + placeholder pages.
- **US2 (Phase 5)**: Depends on US1 (the routes + placeholder pages it replaces).
- **US3 (Phase 6)**: Depends on US2 (it replaces the RoleEditorPage placeholder; reuses the RolesListBloc + repository).
- **US4 (Phase 7, P2)**: Depends on US3 (reuses the role catalog repository + UI scaffolding).
- **US5 (Phase 8)**: Independent of US3/US4 in principle, but the T082 cleanup pass closes the US4 bulk-delete loop using US5's revoke RPC. So Phase 8 lands after Phase 7.
- **Polish (Phase 9)**: Depends on all desired user stories being complete.

### Within Each Phase

- Models / DTOs / entities first.
- Datasources + repository impls next.
- Use cases next.
- BLoCs next.
- Widgets + pages last.
- `build_runner` regen after each new `@injectable` / `@LazySingleton` annotation lands.
- Manual UI walk after the page is wired.
- SQL verification via Supabase MCP `execute_sql` after the page passes manual walk.

### Parallel Opportunities

- **Within Phase 2**: T008 / T009 / T010 (the three policy files) can be written in parallel — they touch different files. T006 / T011 / T013 / T015 / T017 (the five migrations) are sequential because they must apply in order via Supabase MCP.
- **Within Phase 5 (US2)**: T032, T033, T034, T039, T040 are all [P] (entities + abstract repo + DTOs + bloc + card widget) and touch different files.
- **Within Phase 6 (US3)**: T051, T052, T053 are [P] (ARB keys + widget files).
- **Within Phase 8 (US5)**: T067, T068, T069, T074, T075, T076 are all [P].
- **Within Phase 9 (Polish)**: T083 through T087 are all [P] (different `.md` files).

### MVP Boundary

After completing Phases 1 + 2 + 4 (US1), you have:
- All Phase 7 backend migrations applied + first super_admin bootstrapped.
- A super_admin can navigate to the super-admin section.
- Placeholder pages exist for `RolesListPage`, `RoleEditorPage`, `CreateRolePage`, `AssignRolePage`.

This is a valid demo state: the **route guard + RLS + RPC permission re-check are all working**; the UI is empty but functional. Subsequent stories add the actual functionality.

---

## Parallel Example: User Story 2 (Roles List)

```bash
# After Phase 2 (migrations applied) and Phase 4 (US1 placeholder pages), launch:
Task: "T032 [P] [US2] Create domain entities in lib/features/super_admin/domain/entities/"
Task: "T033 [P] [US2] Create abstract RoleCatalogRepository in lib/features/super_admin/domain/repositories/role_catalog_repository.dart"
Task: "T034 [P] [US2] Create DTOs in lib/features/super_admin/data/dtos/"

# After T035, T036, T037 complete sequentially:
Task: "T039 [P] [US2] Create RolesListBloc in lib/features/super_admin/presentation/bloc/roles_list_bloc.dart"
Task: "T040 [P] [US2] Create RoleCard widget in lib/features/super_admin/presentation/widgets/role_card.dart"
```

---

## Implementation Strategy

### MVP First (Phases 1 + 2 + 4 = US1)

1. Complete Phase 1: Setup (T001–T005).
2. Complete Phase 2: Foundational (T006–T019). All backend wired; first super_admin bootstrapped.
3. Complete Phase 4: US1 (T024–T031). Tile + route guard + placeholder pages.
4. **STOP and VALIDATE**: Sign in as super_admin → confirm tile + navigation work; sign in as non-super-admin → confirm everything is hidden. Verify Step 4d defense-in-depth via Supabase MCP.
5. Demo to stakeholders if desired.

### Incremental Delivery

1. MVP (per above) → demo.
2. Add US6 (Phase 3) → backend audit-trail verified → demo via SQL only (no new UI).
3. Add US2 (Phase 5) → `RolesListPage` shows the seven seeded system roles → demo on device.
4. Add US3 (Phase 6) → editor saves edits + handles optimistic-lock + super_admin protection → demo.
5. Add US4 (Phase 7) → custom-role create + delete → demo with the `finance` role from the spec's acceptance criterion.
6. Add US5 (Phase 8) → end-to-end role assignment with mid-session propagation across two devices → final acceptance demo.
7. Polish (Phase 9) → squash-merge.

### Parallel Team Strategy

If two implementers are available after Phase 4 (US1) completes:

- Implementer A: takes US2 (Phase 5) and US3 (Phase 6) sequentially (US3 depends on US2's editor wiring).
- Implementer B: takes US5 (Phase 8). Independent of US2/US3 at the data layer.
- Sync at the start of Phase 9 for the polish + golden-path walk.

US4 (Phase 7) can be picked up by either implementer after US3 completes; it's P2 and could be deferred to the polish phase if time-boxed.

---

## Notes

- [P] tasks = different files, no dependencies between them. Tasks within the same phase that ARE NOT [P] are sequential.
- [Story] label maps a task to its user story for traceability. Setup, Foundational, Polish tasks have NO story label.
- Every backend mutation in Phase 2 is verified via Supabase MCP `execute_sql` immediately after the `apply_migration` call. Do NOT batch the verification.
- Every UI task is paired with a manual walk step against `quickstart.md`. Do NOT mark a UI task done without observing the behavior on the reference Infinix Note 8 device.
- The `flutter pub run build_runner build --delete-conflicting-outputs` command is required after each new `@injectable` / `@LazySingleton` annotation lands. The Phase 7 sequence runs it at T038, T050, T056, T061, T073, T079 — six times total.
- Per Phase 7 R-22 + project memory `project_deferred_work.md`: review `DEFERRED.md` at squash-merge time. Expected content: "No deferrals — Phase 7 ships complete." (matching Phase 6 pattern).
- Per `feedback_git_workflow.md`: Phase 7 ships as ONE squash-merged PR per spec, branch `007-super-admin-roles`, target `main`. Auto-commit hooks run between phases per `.specify/extensions.yml`.
- Per `project_dart_defines.md`: every Flutter run / build during Phase 7 verification MUST include `--dart-define-from-file=.env.json`.
- Per `project_supabase_mcp_apply_migration.md`: every migration is idempotent so re-application via Supabase MCP `apply_migration` is safe. If you accidentally re-apply, the migration tracker creates a duplicate tracker row but the SQL is a no-op due to `CREATE OR REPLACE` / `DROP IF EXISTS … CREATE` constructs.
- The Edge Function `mutate_role` path named in `docs/IMPLEMENTATION_PLAN.md §Phase 7` is **deferred** per Clarifications Q3 / R-06. Do NOT create `supabase/functions/mutate_role/` during Phase 7. The SECURITY DEFINER RPC is the v1 implementation.
- `current_user_is_admin()` body is **unchanged** in Phase 7 (R-17). Do NOT add a `CREATE OR REPLACE FUNCTION current_user_is_admin()` block to any Phase 7 migration.
- Constitution VII (no hardcoded role checks) is enforced by PR review. The optional lint guard from Phase 6 R-21 remains optional in Phase 7; if you encounter time pressure, leave it for Phase 24.
- The 12 permission-category ARB keys are MANDATORY in BOTH `app_ar.arb` and `app_en.arb` — the Phase 3 localization gate blocks merge if a key is missing in either file (T090).
- A cheaper LLM implementing this should: (a) re-read the relevant contract file before starting a task — every file path + SQL body + Dart class skeleton is there verbatim; (b) re-read the corresponding `quickstart.md` step before the verification task; (c) use `Read` on existing Phase 6 files to mirror conventions (especially DI registration, ARB key format, BLoC patterns) rather than inventing new conventions.
- **Migration filename prefixes** `20260516120001..120005` are CANONICAL for this spec; do NOT change them to the current calendar date if you implement on a different day. The prefix's purpose is monotonic ordering after Phase 6's `20260515120008` — not to record the apply date (R-01).
- **Commit cadence**: after each Phase's Checkpoint, the `/speckit-git-commit` hook auto-fires (unless declined). To confirm you are not building up a monolithic diff, run `git log --oneline -15` mid-implementation periodically — expect at least one commit per completed Phase. The Phase 7 PR squash-merges all phase commits into one PR commit per `feedback_git_workflow.md`.
- **Windows-shell note**: the harness runs on Windows + PowerShell. Use the harness's `Grep` tool (NOT a shell `grep` call), `Glob` (NOT shell `find`), `Read` (NOT shell `cat`/`Get-Content`). For shell-only operations, use PowerShell syntax — `$null` not `/dev/null`, `$env:VAR` not `$VAR`, etc.
- **DI accessor pattern is project-specific**: Phase 6 may use `getIt<X>()` OR `context.read<X>()` OR `@injectable` constructor injection. Every Phase 7 task that references DI says "pre-check Phase 6's pattern" — do NOT assume one over the other; match what the project actually ships.
- **`SupabaseClient` accessor**: the Phase 6 codebase wraps Supabase access through `lib/core/network/supabase_client_wrapper.dart` (or similar). Phase 7 tasks reference `supabase` as a shorthand — in actual code, use whatever Phase 6 exposes (likely `wrapper.client` or a `Supabase.instance.client` shorthand). Match exactly.
