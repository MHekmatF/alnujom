# Implementation Plan: Super-Admin Role & Permission Management

**Branch**: `007-super-admin-roles` | **Date**: 2026-05-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/007-super-admin-roles/spec.md`

## Summary

Phase 7 is the in-app super-admin surface on top of the Phase 6 catalog: three new SECURITY DEFINER SQL RPCs (`mutate_role`, `assign_role_to_user`, `revoke_role_from_user`) — applied via Supabase MCP `apply_migration` — that wrap (a) the atomic role-row + role-permissions delta with optimistic locking, super_admin-permission-set immutability, and server-side permission re-check; (b) the user-role assignment with the FR-009 two-step-confirmation enforcement for `super_admin` grants and the unconditional self-revoke block. Phase 7 also attaches three new audit-trigger groups (on `roles`, `role_permissions`, `permissions`) reusing Phase 4's unchanged `log_audit()` function, plus three write-side RLS policy files on the Phase 6 catalog tables (`roles`, `role_permissions`, `user_roles`) gated by `current_user_has_permission(<key>)`. The Phase 6 audit triggers on `user_roles` (`trg_user_roles_audit_granted`, `trg_user_roles_audit_revoked`) and the system-role-immutability trigger (`enforce_role_system_immutability`) continue to fire unchanged — they cover the in-app mutation surface that Phase 7 introduces. The Flutter side adds the first new feature folder of the post-Phase-6 era: `lib/features/super_admin/` with three pages (`RolesListPage`, `RoleEditorPage`, `AssignRolePage`), their BLoCs and use cases, plus a small extension to Phase 6's `permission_keys.dart` for the `superAdminCategoryKeys` constant that gates the new admin-home tile and the `/admin/super-admin/...` route guards. The Phase 6 `AdminHomePage` gets one new tile (visibility-gated by `PermissionChecker.any(superAdminCategoryKeys)`); the Phase 6 `PermissionChecker` lifecycle is unchanged (the three observation points cover the grant→cache-refresh propagation path documented in spec US5 / SC-011). Apply every migration to the **remote** Supabase project via Supabase MCP `apply_migration` (inherited from Phase 4 R-01). Verification is manual SQL inspection via Supabase MCP `execute_sql` + `get_advisors` after each migration + end-to-end manual UI verification on the reference Infinix Note 8 device, all walked by `quickstart.md`.

**Technical approach**: Six Session 2026-05-15 clarifications closed the design space — Q1 (super_admin grants allowed via two-step confirmation), Q2 (self-revocation of `super_admin` blocked unconditionally), Q3 (mutation entry point is a SECURITY DEFINER SQL RPC, not an Edge Function — the IMPLEMENTATION_PLAN.md `mutate_role` Edge Function path is deferred per Constitution XII), Q4 (optimistic locking via the existing Phase 6 `roles.updated_at` token), Q5 (super_admin role's permission set is immutable through `RoleEditorPage` — UI block plus RPC server-side enforcement as defense-in-depth), Q6 (permission-category headings localized via 12 new `permissionCategory<Capitalized>` ARB keys). The deferral of the Edge Function is the single deviation from the implementation plan's literal text — the plan's "Direct SQL also allowed via roles.create RLS" sentence acknowledged the path is permitted; the SECURITY DEFINER RPC achieves the same atomicity guarantee that motivated the Edge Function with zero new deployment infrastructure. The five Phase 7 migrations + the three new policy files + the three new contract files for the RPCs + the seven contract files for tables/triggers/Flutter pages collapse into **5 new migration files** plus **3 new policy files** plus **3 updated doc files** plus **9 contract files** plus **a new feature folder under `lib/features/super_admin/`** plus **a 12-entry ARB key delta on both `app_ar.arb` and `app_en.arb`** plus **2-line extension of `lib/core/security/permission_keys.dart`**. Phase 4 R-05 / Phase 6 R-05 central-helper invariant continues to hold: `current_user_is_admin()` is unchanged (Phase 6 was the last planned body swap per the `admin-predicate-v6.md` contract). The `log_audit()` reusable trigger function is invoked unchanged for the three new audit-trigger groups (Phase 4 R-05 reusability invariant preserved a third time across Phases 4/5/6/7). The Flutter side adds `lib/features/super_admin/{data,domain,presentation}/` strictly per Constitution IV; the `domain/` of the new feature is Supabase-free per Constitution IX. **No new packages in `pubspec.yaml`**. **No new automated tests** per the durable session feedback rule (`feedback_no_new_tests.md`); verification is manual SQL via Supabase MCP `execute_sql` + `get_advisors` + manual device walk on the reference Infinix Note 8 against the remote Supabase project.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel) for the app additions; PostgreSQL (Supabase remote, Postgres 15+) for the SQL migrations. **No Edge Function in Phase 7** per Clarifications Session 2026-05-15 Q3 — the deviation from the implementation plan's literal text is recorded in spec assumptions and in research R-06. Same Flutter + Dart base as Phases 1–6.

**Primary Dependencies**: `supabase_flutter` (already in `pubspec.yaml`), `flutter_bloc` (already in), `equatable` (already in), `get_it` + `injectable` (already in — used for DI registration of the new BLoCs, use cases, and data sources via codegen), `go_router` (already in — the new `/admin/super-admin/...` route guards read from `PermissionChecker.any(...)`). **No new runtime or dev packages.** **Tooling**: Supabase MCP server (`apply_migration`, `execute_sql`, `list_tables`, `list_migrations`, `get_advisors`) is the canonical migration-apply / inspection mechanism — same as Phases 4, 5, 6.

**Storage**: Remote Supabase Postgres project. Phase 7 adds:

- **Three SECURITY DEFINER SQL RPCs**: `mutate_role(op TEXT, role_id UUID, role_key TEXT, display_name JSONB, description TEXT, permission_keys TEXT[], expected_updated_at TIMESTAMPTZ) RETURNS JSONB` (FR-008); `assign_role_to_user(target_user_id UUID, target_role_id UUID, confirmation_token TEXT) RETURNS JSONB` (FR-009); `revoke_role_from_user(target_user_id UUID, target_role_id UUID) RETURNS JSONB` (FR-009). All `LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth`; all re-check permissions via `current_user_has_permission(<key>)`; all execute their writes inside the implicit transaction so the Phase 6 + Phase 7 audit triggers produce the correct row sequences automatically; all `REVOKE`d from `PUBLIC`/`anon` and explicitly `GRANT`ed to `authenticated` in the advisor-hardening migration.
- **Three new audit-trigger groups**: triggers on `public.roles` (INSERT/UPDATE/DELETE → `role.created` / `role.updated` / `role.deleted` — FR-001); on `public.role_permissions` (INSERT/DELETE → `role_permission.granted` / `role_permission.revoked` — FR-002); on `public.permissions` (INSERT/UPDATE/DELETE → `permission.created` / `permission.updated` / `permission.deleted` — FR-003, defensive). All attached via Phase 4's `log_audit()` reusable trigger function (unchanged for a third time across Phases 4/5/6/7).
- **Three new write-side RLS policy files**: `roles_phase7_write.sql` (INSERT requires `roles.create`; UPDATE requires `roles.update`; DELETE requires `roles.delete` — FR-004); `role_permissions_phase7_write.sql` (INSERT/DELETE require `permissions.manage` — FR-005); `user_roles_phase7_write.sql` (INSERT/DELETE require `permissions.manage` — FR-006). The existing Phase 6 read policies on the same tables are NOT edited; the new write policies stack on top per the Phase 4 R-05 invariant.
- **Two extensions of Phase 6's `roles.updated_at` semantics**: the `mutate_role` RPC reads + compares `expected_updated_at` against the live row before mutation, raising `40001 serialization_failure` on mismatch (FR-008 — Clarifications Q4). The Phase 4 `set_updated_at` trigger continues to advance the column on every UPDATE of `roles`.
- **No new tables, no new columns, no new helper functions** beyond the three RPCs. The Phase 6 helpers (`current_user_has_permission`, `current_user_is_admin`) and Phase 6 triggers (`trg_user_roles_audit_granted`, `trg_user_roles_audit_revoked`, `enforce_role_system_immutability`, `trg_profiles_auto_user_role`) continue to operate unchanged.

**Testing**: **Manual SQL inspection against the remote Supabase project via Supabase MCP `execute_sql` + `get_advisors` after each migration + manual UI verification on the reference Infinix Note 8 device.** Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's assumptions, this phase introduces NO new automated tests of any kind. Build-time validation is preserved: Supabase's static SQL parser at `apply_migration` time catches syntax errors; Flutter's analyzer + the existing Phase 3 localization lint guard validate the new Dart files. Existing Phase 1/2/3/4/5/6 tests remain in source unchanged.

**Target Platform**: Android 7.0+ (API 24+) for the Flutter side (Constitution XI); Supabase remote Postgres for the backend side. iOS, Web, desktop NOT a target.

**Project Type**: Mobile app + backend. Phase 7 introduces the first new feature-folder top-level since Phase 5/6 (`lib/features/super_admin/`). It also adds a single new tile to the Phase 6 `AdminHomePage`, extends Phase 6's `permission_keys.dart`, and adds 12+~6 ARB keys to both `app_ar.arb` and `app_en.arb`.

**Performance Goals**:

- `mutate_role` RPC end-to-end latency for a typical edit (10-permission delta against a single role): under 200ms server-side + one round-trip from the device against the remote project; under 1 second total observed on the reference Infinix Note 8 on a typical mobile connection.
- `assign_role_to_user` / `revoke_role_from_user` RPC latency: under 100ms server-side + one round-trip; under 500ms total observed on the device.
- `RolesListPage` initial render: under 2 seconds on the reference device (one read of `SELECT * FROM roles ORDER BY key` plus a roll-up COUNT against `role_permissions` per row — a small query at MVP scale).
- `RoleEditorPage` open: under 2 seconds on the reference device (one read of the role + one read of its current `role_permissions` rows + the cached `PermissionChecker` set for super_admin entitlements).
- `AssignRolePage` user search debounce: 300ms after last keystroke; result-set capped at 50 rows server-side; under 1 second total per search round-trip.
- Mid-session permission propagation on the target user's device (Phase 6 FR-015 lifecycle-resume path): the new admin tile appears within a few seconds of foregrounding the app after the grant. The Phase 6 spec SC-010 / SC-011 / Phase 7 spec SC-011 verifies the observable behavior; no new mechanism in Phase 7.
- Migration apply (five migrations) against the remote project: under 30 seconds total.

**Constraints**:

- Constitution II (Source-Controlled Backend) is binding: every backend artifact is a checked-in `.sql` file under `supabase/migrations/` or `supabase/policies/`. No Studio-only edits (FR-014).
- Constitution III (Security-First Supabase, NON-NEGOTIABLE): the three new RPCs are `SECURITY DEFINER STABLE` (where STABLE is correct — for `mutate_role` it must be `VOLATILE` because it writes) `SET search_path=public,auth`. All three RPCs `REVOKE EXECUTE` from `PUBLIC, anon` in the advisor-hardening migration and explicitly `GRANT EXECUTE TO authenticated`. The write-side RLS policies on `roles`, `role_permissions`, `user_roles` are permission-keyed via `current_user_has_permission(<key>)` and stack on top of the existing Phase 6 read policies; no Phase 6 policy file is edited. The Phase 6 `enforce_role_system_immutability` trigger continues to provide defense-in-depth for system-row deletes/renames.
- Constitution VII (Dynamic Roles & Permissions) is the principle this phase realizes a second time: no hardcoded role checks in feature code (FR-016); every UI gate consults `PermissionChecker.has(...)`; every RLS gate consults `current_user_has_permission(<specific key>)`; audit emission is universal (every roles / role_permissions / user_roles / permissions mutation produces exactly one `audit_logs` row).
- Constitution VIII (Approval Workflow & Publisher Identity): Phase 7's super-admin UI is the only in-app surface that can mutate the role/permission graph; the surface is super-admin-gated; every mutation is audit-trailed; the Phase 5 publisher-identity invariants are untouched.
- Constitution IX (Future Backend Portability): `lib/features/super_admin/domain/` imports nothing from `package:supabase_flutter`. Only `lib/features/super_admin/data/datasources/...` and `lib/features/super_admin/data/repositories/...` touch Supabase.
- Migrations apply to the **remote** Supabase project via Supabase MCP `apply_migration` (inherited from Phase 4 R-01).
- Migrations MUST be idempotent (Supabase migration tracker + idempotent constructs in the bodies: `CREATE OR REPLACE FUNCTION`, `DROP TRIGGER IF EXISTS ... CREATE TRIGGER`, `DROP POLICY IF EXISTS ... CREATE POLICY`). The project memory `project_supabase_mcp_apply_migration.md` is binding.
- Phase 4 R-05 / Phase 5 R-12 / Phase 6 R-05 central-helper invariant is preserved a third time: `current_user_is_admin()` is unchanged in Phase 7; `current_user_has_permission()` is unchanged; new policies use the helpers as-is.
- The `log_audit()` reusable trigger function is invoked unchanged for the three new audit-trigger groups (Phase 4 R-05 reusability invariant preserved a third time).
- First super_admin is created post-Phase-6 via privileged SQL (Phase 6 Q1 clarification — Option C). Phase 7 docs that step in `quickstart.md` as an entry condition for the surface to be useful. The bootstrap is a one-time deploy action, not a recurring Phase 7 operation.
- super_admin grants from `AssignRolePage` are allowed but require two-step confirmation (Clarifications Q1).
- Self-revocation of `super_admin` is blocked unconditionally — UI hides the affordance; `revoke_role_from_user` RPC rejects with `42501` (Clarifications Q2).
- `mutate_role` is a SECURITY DEFINER RPC, not an Edge Function (Clarifications Q3 — deviation from IMPLEMENTATION_PLAN.md literal text is recorded per Constitution XII).
- Optimistic locking on `roles.updated_at` is the concurrent-edit-conflict policy (Clarifications Q4).
- The `super_admin` role's permission mapping is immutable through `RoleEditorPage` and through `mutate_role` (Clarifications Q5).
- Permission-category headings are localized via ARB keys, no DB schema change (Clarifications Q6).
- No new packages in `pubspec.yaml`; no new dev packages.
- The hardcoded-role-check forbidden pattern (Constitution VII / FR-016) is enforced by PR review in Phase 7; the Phase 3 lint-guard extension remains OPTIONAL (Phase 6 R-21 carried forward).

**Scale/Scope**:

- **Five new SQL migration files** under `supabase/migrations/` named with synthetic-monotonic 14-digit timestamps `20260516120001` through `20260516120005`, ordered after Phase 6's `20260515120008_phase6_advisor_hardening.sql`. The five migrations:
  1. `20260516120001_create_phase7_audit_triggers.sql` — three trigger groups (on `roles`, `role_permissions`, `permissions`) via Phase 4's `log_audit()` function. Each AFTER trigger passes the full action key as `TG_ARGV[0]`, `'*'` for the columns-to-capture, and `'id'` (`roles`, `permissions`) or `'role_id'` (`role_permissions`) for the target column. Phase 6's existing `user_roles` triggers are NOT touched. (FR-001, FR-002, FR-003.)
  2. `20260516120002_create_phase7_write_policies.sql` — bundled inline + parallel policy files at `supabase/policies/roles_phase7_write.sql`, `role_permissions_phase7_write.sql`, `user_roles_phase7_write.sql`. INSERT/UPDATE/DELETE policies on `roles` gated by `current_user_has_permission('roles.create' | 'roles.update' | 'roles.delete')`; INSERT/DELETE on `role_permissions` gated by `current_user_has_permission('permissions.manage')`; INSERT/DELETE on `user_roles` gated by `current_user_has_permission('permissions.manage')`. (FR-004, FR-005, FR-006.)
  3. `20260516120003_create_mutate_role_rpc.sql` — `CREATE OR REPLACE FUNCTION public.mutate_role(op TEXT, role_id UUID, role_key TEXT, display_name JSONB, description TEXT, permission_keys TEXT[], expected_updated_at TIMESTAMPTZ) RETURNS JSONB LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=public,auth` with the body per FR-008 and the optimistic-locking + super_admin-permission-set-immutability checks per Clarifications Q4 + Q5. (FR-008.)
  4. `20260516120004_create_user_role_assignment_rpcs.sql` — `CREATE OR REPLACE FUNCTION public.assign_role_to_user(target_user_id UUID, target_role_id UUID, confirmation_token TEXT) RETURNS JSONB` AND `CREATE OR REPLACE FUNCTION public.revoke_role_from_user(target_user_id UUID, target_role_id UUID) RETURNS JSONB`. Both `LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=public,auth`. The assign function enforces the two-step `super_admin` confirmation (Clarifications Q1) — when `target_role_id = super_admin.id`, the function reads the target user's phone/username from `profiles` and compares with `confirmation_token`, rejecting on mismatch with `42501` and a structured error code; the revoke function enforces the unconditional `super_admin` self-revoke block (Clarifications Q2) — when `target_role_id = super_admin.id AND auth.uid() = target_user_id`, it raises `42501`. (FR-009.)
  5. `20260516120005_phase7_advisor_hardening.sql` — defense-in-depth (mirroring Phase 5 R-12 + Phase 6 R-12 advisor-hardening pattern). `REVOKE EXECUTE ON FUNCTION mutate_role(...) FROM PUBLIC, anon`; `REVOKE` from the two assignment RPCs; explicit `GRANT EXECUTE TO authenticated` on all three; ensures none of the Phase 7 RPCs leak to unauthenticated callers.

- **Three new policy files** under `supabase/policies/` (parallel to the inline-bundled CREATE POLICY statements in migration 2 — same shape as Phase 6 R-02): `roles_phase7_write.sql`, `role_permissions_phase7_write.sql`, `user_roles_phase7_write.sql`. Phase 6 policy files are NOT edited.

- **Three updated doc files** under `supabase/docs/`: `roles.md` (note the new write-side RLS policies + new audit-trigger group); `role_permissions.md` (note the new write-side RLS policies + new audit-trigger group + the `mutate_role` RPC); `user_roles.md` (note the new write-side RLS policies + the two assignment RPCs + reaffirm the Phase 6 audit-trigger coverage); `permissions.md` (note the new defensive audit-trigger group; reaffirm immutability in v1 — the trigger fires only if a future migration mutates the catalog). `audit_logs.md` is also updated to enumerate the seven new action keys from Phase 7 (`role.created`, `role.updated`, `role.deleted`, `role_permission.granted`, `role_permission.revoked`, `permission.created` / `.updated` / `.deleted`).

- **One new Dart file** under `lib/core/security/`: a 2-line addition to `permission_keys.dart` — the `static const Set<String> superAdminCategoryKeys = {rolesView, rolesCreate, rolesUpdate, rolesDelete, permissionsManage}` constant (FR-012). No other change to the existing 24 constants.

- **One new feature folder** under `lib/features/super_admin/` with the full Constitution IV three-layer split (`data/`, `domain/`, `presentation/`). Subfiles:

  - `data/datasources/supabase_role_catalog_datasource.dart` — reads all roles + their permission counts; reads a single role's full permissions; calls `mutate_role` RPC; calls `assign_role_to_user` / `revoke_role_from_user` RPCs.
  - `data/datasources/supabase_user_search_datasource.dart` — fulltext search across `profiles` by phone (E.164) or `username` substring; cap 50 rows; cross-user read admitted by the Phase 6 `users.view` policy because super_admin holds it via the full-catalog mapping.
  - `data/repositories/role_catalog_repository_impl.dart`, `user_search_repository_impl.dart` — the only places that import `package:supabase_flutter` in the new feature folder.
  - `data/dtos/role_dto.dart`, `permission_dto.dart`, `user_search_result_dto.dart`, `mutate_role_request_dto.dart`, `assign_role_request_dto.dart` — Supabase-shape DTOs.
  - `domain/entities/role_with_counts.dart`, `role_detail.dart`, `permission_catalog_entry.dart`, `user_search_result.dart`, `role_mutation_result.dart`, `role_assignment_result.dart` — domain value objects. NO Supabase imports.
  - `domain/repositories/role_catalog_repository.dart`, `user_search_repository.dart` — abstract interfaces.
  - `domain/usecases/list_roles.dart`, `load_role_detail.dart`, `mutate_role.dart`, `delete_role.dart`, `search_users.dart`, `load_user_assignments.dart`, `assign_role_to_user.dart`, `revoke_role_from_user.dart` — one use case per primary action.
  - `presentation/bloc/roles_list_bloc.dart` — owns the list state for `RolesListPage`.
  - `presentation/bloc/role_editor_bloc.dart` — owns the editor state for `RoleEditorPage` including the optimistic-locking token (`expected_updated_at`) captured on open, the unsaved permission delta, the unsaved display_name / description edits, and the save-conflict / save-immutability error states.
  - `presentation/bloc/assign_role_bloc.dart` — owns the search results state + per-user role-management drawer state for `AssignRolePage`, including the two-step `super_admin` confirmation flow.
  - `presentation/pages/roles_list_page.dart`, `role_editor_page.dart`, `create_role_page.dart`, `assign_role_page.dart` — the four pages.
  - `presentation/widgets/role_card.dart`, `permission_checklist.dart`, `permission_category_header.dart`, `confirmation_dialog.dart`, `super_admin_grant_confirmation_dialog.dart`, `assigned_role_row.dart`, `user_search_field.dart` — the new widgets. All consume Phase 2 design tokens + Phase 3 `AppLocalizations`.

- **One updated existing file**: `lib/features/admin/presentation/pages/admin_home_page.dart` gains one new tile "Super-admin" gated by `PermissionChecker.any(PermissionKeys.superAdminCategoryKeys)`. Tapping it navigates to `/admin/super-admin/roles` (the `RolesListPage` is the entry point per FR-010 and R-15).

- **One updated existing file**: `lib/core/routing/auth_redirect.dart` (or the go_router config equivalent) gains four new route entries — `/admin/super-admin/roles`, `/admin/super-admin/roles/:roleId`, `/admin/super-admin/roles/create`, `/admin/super-admin/assign` — each with a redirect guard reading `PermissionChecker.any(PermissionKeys.superAdminCategoryKeys)` and falling through to the per-button per-action gate inside each page.

- **ARB key delta** on `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`: 12 permission-category headings (`permissionCategoryUsers` / `permissionCategoryListings` / `permissionCategoryRoles` / `permissionCategoryLocations` / `permissionCategoryCurrencies` / `permissionCategoryAds` / `permissionCategoryReports` / `permissionCategoryAgencies` / `permissionCategorySettings` / `permissionCategoryAudit` / `permissionCategoryInquiries` / `permissionCategoryPermissions`) per FR-010 / Clarifications Q6, plus approximately 25–30 additional UI strings for the new pages, buttons, validation errors, confirmation dialogs, and the structured-error-code-to-user-message map. All keys ship to both ARB files in the same commit per Phase 3's localization gate.

- **0 new packages** in `pubspec.yaml`.

- **0 new tests** (durable no-new-tests rule).

- **0 changes** to `.github/workflows/ci.yml` (no new tooling needs CI; SQL is validated at `apply_migration` time on the remote).

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists; `/speckit-specify` resolved Q1/Q2/Q3 (super_admin grants, self-revoke guard, RPC vs Edge Function); `/speckit-clarify` resolved Q4/Q5/Q6 (concurrent edits, super_admin permission-set immutability, category l10n). No implementation has begun. |
| II. Source-Controlled Backend | **Pass** | Every Phase 7 backend artifact lives as a checked-in file: 5 migrations under `supabase/migrations/`, 3 new policy files under `supabase/policies/`, doc updates under `supabase/docs/`. No artifact lives only in Studio (FR-014). The first super_admin bootstrap (privileged SQL via Supabase MCP `execute_sql`) is documented in `quickstart.md` as a one-time post-deploy operational action carried forward from Phase 6 — not a schema artifact. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | RLS is already enabled on all four Phase 6 tables; Phase 7 adds the write-side policies that complete the gating (FR-004/005/006). The three new SECURITY DEFINER RPCs `REVOKE EXECUTE FROM PUBLIC, anon` and explicitly `GRANT TO authenticated` (Phase 5 R-12 + Phase 6 R-12 advisor-hardening pattern carried forward to migration 5). The `mutate_role` RPC implements optimistic-lock + super_admin-permission-set-immutability defense-in-depth on top of the RLS policies. The `revoke_role_from_user` RPC implements the unconditional self-revoke block. The `assign_role_to_user` RPC implements the two-step `super_admin` confirmation gate server-side (the UI is the first gate; the server is defense-in-depth). The Phase 6 `enforce_role_system_immutability` trigger continues to fire for any DELETE of `is_system=true` rows even when reached via the new write-side RLS policies. No Phase 6 policy file is edited. |
| IV. Clean Architecture Flutter | **Pass** | `lib/features/super_admin/` is a full three-layer Clean Architecture feature folder (`data/`, `domain/`, `presentation/`). BLoCs own state; use cases live in `domain/usecases/`; repositories are abstract in `domain/repositories/` with Supabase-touching impls in `data/repositories/`. No widget calls Supabase; no use case imports Supabase. |
| V. Arabic-First Localization | **Pass** | All ~37 new user-visible strings flow through Phase 3's `AppLocalizations`. The 12 `permissionCategory<Capitalized>` keys, the ~25 page/button/dialog/validation-error strings, and the structured-error-code-to-user-message map all ship in both `app_ar.arb` and `app_en.arb` in the same commit. RTL is honored: confirmations use `EdgeInsetsDirectional`; the user-search input uses `Directionality`-aware text alignment. |
| VI. Theme System & Design Tokens | **Pass** | The new pages consume Phase 2's `ListTile` / Chip / Card / Button / Dialog primitives. The permission checklist's category headers consume the existing typography tokens. No inline hex / font-size / padding in any new widget under `lib/features/super_admin/presentation/widgets/`. |
| VII. Dynamic Roles & Permissions | **Pass — this is the principle this phase realizes a second time.** | Phase 7's super-admin UI is the in-app mutation surface for the data-driven role/permission graph established in Phase 6. Every action is gated by a permission-key check on both ends: client-side `PermissionChecker.has(<key>)` for UX hiding; server-side `current_user_has_permission(<key>)` inside the RPC + the new write-side RLS policies. Hardcoded role checks remain forbidden (FR-016) and enforced by PR review. The audit-trail coverage expansion (FR-001/002/003) realizes the constitution's "audit-log entry capturing actor, action, target, timestamp, and before/after state" mandate for the mutation surface — every Phase 7 mutation produces an `audit_logs` row. |
| VIII. Approval Workflow & Publisher Identity | **Pass** | Phase 7 does not touch the approval workflow itself. The new super-admin surface is super-admin-gated; it cannot impersonate or bypass any approval step. The Phase 5 PII admin-only invariant is preserved (no Phase 7 helper changes the Phase 5 `app_vault_secret_for_user` gate). The cross-user `profiles` read for the `AssignRolePage` search uses the existing Phase 6 `users.view`-gated policy. |
| IX. Future Backend Portability | **Pass** | `lib/features/super_admin/domain/` imports nothing from `package:supabase_flutter` — `grep -R "package:supabase_flutter" lib/features/super_admin/domain` returns zero results post-implementation (SC-019). Only `lib/features/super_admin/data/datasources/*` and `lib/features/super_admin/data/repositories/*` touch Supabase types. The `lib/core/security/permission_keys.dart` extension is pure Dart. |
| X. Testable AI Workflow | **Pass — Justified.** | Per `feedback_no_new_tests.md` carried forward from Phases 3/4/5/6, every FR is verifiable via a manual SQL action with expected output OR via Supabase MCP `execute_sql` / `list_tables` / `get_advisors` calls OR via a manual UI walk on the reference device. The constitution explicitly permits "a SQL query with expected output" or "a UI action with expected screen state" as acceptance steps. `quickstart.md` lists per-FR / per-SC verifications as runnable Supabase MCP calls and device-walk steps. No constitutional amendment is required. |
| XI. Android-First MVP | **Pass** | All Flutter additions target the Android Flutter build only; no platform-conditional code. The remote Supabase backend is platform-neutral. No new platform plugins. |
| XII. No Hidden Product Decisions | **Pass** | All six Session 2026-05-15 clarifications are captured in `spec.md` `## Clarifications`. The single deviation from the implementation plan's literal Phase 7 text (the `mutate_role` Edge Function vs SECURITY DEFINER RPC choice) is captured in Clarifications Q3 with the rationale, in `spec.md` Edge Cases, Assumptions, and Constitution Check Note. The deferral of the Edge Function path is recorded; the implementation plan's parenthetical "Direct SQL also allowed via roles.create RLS" sentence acknowledged the deviation is permitted. The DEFERRED.md file (authored during implement, reviewed at squash-merge time per project memory `project_deferred_work.md`) captures any in-flight scope decisions. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

## Project Structure

### Documentation (this feature)

```text
specs/007-super-admin-roles/
├── plan.md                    # This file
├── research.md                # Phase 0 — locked tech decisions (R-01..R-22)
├── data-model.md              # Phase 1 — the 3 new RPCs, the 3 new audit-trigger groups, the 3 new write-policy files, the permission_keys.dart delta, the BLoC + entity shapes for the new feature folder
├── quickstart.md              # Phase 1 — end-to-end manual verification recipe via Supabase MCP execute_sql + Flutter device walk on Infinix Note 8
├── contracts/                 # Phase 1 — interface contracts the implementation MUST honor
│   ├── phase7-audit-triggers.md           # 3 trigger groups (on roles, role_permissions, permissions) reusing log_audit() unchanged
│   ├── phase7-write-policies.md           # write-side RLS on roles, role_permissions, user_roles (gated by current_user_has_permission(<key>))
│   ├── mutate-role-rpc.md                 # SECURITY DEFINER RPC contract: signature, args, permission re-checks, optimistic-lock, super_admin-perm-immutability, error codes
│   ├── assign-role-to-user-rpc.md         # SECURITY DEFINER RPC contract: signature, two-step super_admin confirmation, error codes
│   ├── revoke-role-from-user-rpc.md       # SECURITY DEFINER RPC contract: signature, unconditional self-revoke block, error codes
│   ├── super-admin-routing.md             # admin-home tile visibility + 4 new go_router routes + route-guard logic
│   ├── role-editor-page.md                # Page contract: optimistic-lock token capture, super_admin checklist read-only, save flow, conflict reload UX
│   ├── assign-role-page.md                # Page contract: user search + role-management drawer + two-step super_admin grant + revoke confirmation + self-row super_admin-revoke affordance hidden
│   └── permission-category-localization.md # ARB-key pattern for the 12 category headings + fallback rule
├── checklists/
│   └── requirements.md        # From /speckit-specify (validated; updated post-clarify)
├── spec.md                    # From /speckit-specify + /speckit-clarify (Q1-Q6 resolved Session 2026-05-15)
├── tasks.md                   # Created by /speckit-tasks (NOT by /speckit-plan)
├── DEFERRED.md                # Created during /speckit-implement; reviewed at squash-merge per project_deferred_work.md
└── HANDOFF.md                 # Created at /speckit-implement close-out (or omit if no follow-up scope)
```

### Source Code (repository root)

```text
supabase/
├── config.toml                                            # (existing) NO CHANGE in Phase 7.
├── seed.sql                                               # (existing) NO CHANGE — Phase 7 introduces no new seed data.
├── migrations/
│   ├── 00000000000000_init_extensions.sql                 # (existing — Phase 1) NO CHANGE.
│   ├── 20260506120001_init_enums.sql ... 20260506120006_enable_vault.sql  # (existing — Phase 4) NO CHANGE.
│   ├── 20260510120001_create_account_approval_requests.sql ... 20260510120006_phase5_advisor_hardening.sql # (existing — Phase 5) NO CHANGE.
│   ├── 20260515120001_create_roles.sql ... 20260515120008_phase6_advisor_hardening.sql # (existing — Phase 6) NO CHANGE.
│   ├── 20260516120001_create_phase7_audit_triggers.sql    # NEW — three trigger groups: (a) on `roles` AFTER INSERT/UPDATE/DELETE calling log_audit('role.created'|'role.updated'|'role.deleted', '*', 'id'); (b) on `role_permissions` AFTER INSERT/DELETE calling log_audit('role_permission.granted'|'role_permission.revoked', '*', 'role_id'); (c) on `permissions` AFTER INSERT/UPDATE/DELETE calling log_audit('permission.created'|'permission.updated'|'permission.deleted', '*', 'id'). DROP TRIGGER IF EXISTS … CREATE TRIGGER … for idempotency. Phase 6's trg_user_roles_audit_granted / trg_user_roles_audit_revoked / enforce_role_system_immutability / trg_profiles_auto_user_role are NOT touched. (FR-001, FR-002, FR-003.)
│   ├── 20260516120002_create_phase7_write_policies.sql    # NEW — bundled inline CREATE POLICY statements; the same SQL also written to supabase/policies/roles_phase7_write.sql, role_permissions_phase7_write.sql, user_roles_phase7_write.sql (R-02 Phase 6 invariant — policies live in both source-of-truth files AND inline in the migration). Phase 6 policy files NOT edited. (FR-004, FR-005, FR-006, FR-007.)
│   ├── 20260516120003_create_mutate_role_rpc.sql          # NEW — CREATE OR REPLACE FUNCTION public.mutate_role(op TEXT, role_id UUID, role_key TEXT, display_name JSONB, description TEXT, permission_keys TEXT[], expected_updated_at TIMESTAMPTZ) RETURNS JSONB LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=public,auth. Body implements: server-side permission re-check via current_user_has_permission(<key>); optimistic-lock check via expected_updated_at vs roles.updated_at (Clarifications Q4 — raise 40001 on mismatch for op IN ('update','delete')); super_admin-permission-set-immutability check (Clarifications Q5 — when role_id = super_admin row and op = 'update' and permission_keys differs from current set, raise 42501); the role-row mutation + role_permissions delta in one implicit transaction; returns JSONB with the resulting role row + applied permission keys. (FR-008.)
│   ├── 20260516120004_create_user_role_assignment_rpcs.sql # NEW — two CREATE OR REPLACE FUNCTION blocks: (a) public.assign_role_to_user(target_user_id UUID, target_role_id UUID, confirmation_token TEXT) RETURNS JSONB — re-checks permissions.manage via current_user_has_permission; for target_role_id = super_admin, validates confirmation_token matches profiles.phone or profiles.username for target_user_id (Clarifications Q1) and rejects on mismatch with 42501; INSERTs into user_roles with granted_by = auth.uid(); Phase 6's trg_user_roles_audit_granted fires automatically. (b) public.revoke_role_from_user(target_user_id UUID, target_role_id UUID) RETURNS JSONB — re-checks permissions.manage; for target_role_id = super_admin AND auth.uid() = target_user_id, raises 42501 (Clarifications Q2 — unconditional self-revoke block); DELETEs from user_roles; Phase 6's trg_user_roles_audit_revoked fires automatically. Both functions LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=public,auth. (FR-009.)
│   └── 20260516120005_phase7_advisor_hardening.sql        # NEW — defense-in-depth REVOKE/GRANT pass mirroring Phase 5 R-12 + Phase 6 R-12: REVOKE EXECUTE ON FUNCTION mutate_role(TEXT, UUID, TEXT, JSONB, TEXT, TEXT[], TIMESTAMPTZ) FROM PUBLIC, anon; same for assign_role_to_user, revoke_role_from_user; explicit GRANT EXECUTE TO authenticated on all three. (Constitution III defense-in-depth.)
├── policies/                                              # (existing dir from Phase 4)
│   ├── (existing Phase 4/5/6 policy files)                # NO CHANGE — Phase 4, 5, 6 policy files are NOT edited (central-helper invariant + no-policy-edits invariant preserved a third time).
│   ├── roles_phase7_write.sql                             # NEW — INSERT/UPDATE/DELETE policies on `roles` gated by current_user_has_permission('roles.create' | 'roles.update' | 'roles.delete'). Stacks on top of Phase 6's authenticated-read policy.
│   ├── role_permissions_phase7_write.sql                  # NEW — INSERT/DELETE policies on `role_permissions` gated by current_user_has_permission('permissions.manage'). No UPDATE policy (rows are immutable per Phase 6 R-15 invariant).
│   └── user_roles_phase7_write.sql                        # NEW — INSERT/DELETE policies on `user_roles` gated by current_user_has_permission('permissions.manage'). No UPDATE policy. Phase 6's self-read + admin-cross-read policies are preserved.
├── functions/                                             # (existing dir from Phase 5)
│   └── request_password_reset/                            # (existing — Phase 5) NO CHANGE in Phase 7. The deferred-by-design `mutate_role` Edge Function is NOT created (Clarifications Q3).
└── docs/                                                  # (existing dir from Phase 4/5/6)
    ├── (existing Phase 4/5 doc files)                     # NO CHANGE.
    ├── roles.md                                           # UPDATE — note the new Phase 7 write-side RLS policies; note the new audit-trigger group (`role.created` / `role.updated` / `role.deleted` action keys); note the `mutate_role` RPC is the canonical mutation surface.
    ├── permissions.md                                     # UPDATE — note the new defensive audit-trigger group; reaffirm immutability in v1 (the trigger fires only if a future migration mutates the catalog).
    ├── role_permissions.md                                # UPDATE — note the new Phase 7 write-side RLS policies; note the new audit-trigger group (`role_permission.granted` / `role_permission.revoked`); note the `mutate_role` RPC computes the delta.
    ├── user_roles.md                                      # UPDATE — note the new Phase 7 write-side RLS policies; reaffirm Phase 6's audit-trigger coverage (no Phase 7 trigger added on user_roles); note the two new assignment RPCs as the canonical in-app mutation surface; note the two-step super_admin confirmation contract; note the unconditional super_admin self-revoke block.
    └── audit_logs.md                                      # UPDATE — enumerate the seven new action keys: `role.created`, `role.updated`, `role.deleted`, `role_permission.granted`, `role_permission.revoked`, `permission.created`, `permission.updated`, `permission.deleted`.

lib/
├── main.dart                                              # (existing) NO CHANGE.
├── app.dart                                               # UPDATE — register four new go_router routes under /admin/super-admin/...; each carries a redirect guard reading PermissionChecker.any(PermissionKeys.superAdminCategoryKeys).
├── core/                                                  # (existing)
│   ├── di/
│   │   ├── injection.dart                                 # NO CHANGE — Phase 7's new services use @injectable annotations at their definition sites; injection.config.dart regenerates automatically.
│   │   └── injection.config.dart                          # AUTO-REGEN — codegen file. Phase 7 adds entries for RoleCatalogRepositoryImpl, UserSearchRepositoryImpl, the 8 use cases, and the 3 BLoCs. Run `flutter pub run build_runner build --delete-conflicting-outputs` after the source-side annotations are added.
│   ├── routing/
│   │   └── auth_redirect.dart                             # UPDATE — extend the existing per-route redirect helper with the 4 new super-admin routes. Pattern is identical to Phase 6's /admin route guard.
│   └── security/
│       ├── permission_checker.dart                        # NO CHANGE — Phase 6 PermissionChecker is consumed as-is. No new lifecycle hooks.
│       ├── permission_keys.dart                           # UPDATE — add `static const Set<String> superAdminCategoryKeys = {rolesView, rolesCreate, rolesUpdate, rolesDelete, permissionsManage};` next to the existing `adminCategoryKeys` constant. (FR-012.)
│       ├── permission_catalog_repository.dart             # NO CHANGE — Phase 6 abstract repository.
│       └── permission_catalog_repository_impl.dart        # NO CHANGE — Phase 6 impl.
├── features/                                              # (existing)
│   ├── admin/                                             # (existing — Phase 5 + Phase 6)
│   │   └── presentation/
│   │       └── pages/
│   │           └── admin_home_page.dart                   # UPDATE — add one new tile "Super-admin" gated by PermissionChecker.any(PermissionKeys.superAdminCategoryKeys); tapping it navigates to /admin/super-admin/roles. The empty-state copy from Phase 6 still applies (admins who don't hold any tile-gating permissions see an empty list).
│   └── super_admin/                                       # NEW — Phase 7 feature folder. Full Constitution IV three-layer split.
│       ├── data/
│       │   ├── datasources/
│       │   │   ├── supabase_role_catalog_datasource.dart  # Reads roles list + permission counts via a single Postgrest select; reads role detail (role + its permissions) via a join; calls mutate_role / assign_role_to_user / revoke_role_from_user via supabase.rpc(...).
│       │   │   └── supabase_user_search_datasource.dart   # Searches profiles by phone (E.164 prefix-match) OR username (ILIKE substring); caps result to 50 rows; reads via Phase 6's cross-user users.view-gated policy.
│       │   ├── dtos/
│       │   │   ├── role_dto.dart
│       │   │   ├── permission_dto.dart
│       │   │   ├── role_with_counts_dto.dart
│       │   │   ├── user_search_result_dto.dart
│       │   │   ├── mutate_role_request_dto.dart
│       │   │   ├── assign_role_request_dto.dart
│       │   │   └── role_mutation_response_dto.dart
│       │   └── repositories/
│       │       ├── role_catalog_repository_impl.dart
│       │       └── user_search_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── role_with_counts.dart
│       │   │   ├── role_detail.dart
│       │   │   ├── permission_catalog_entry.dart
│       │   │   ├── user_search_result.dart
│       │   │   ├── role_mutation_result.dart
│       │   │   └── role_assignment_result.dart
│       │   ├── repositories/
│       │   │   ├── role_catalog_repository.dart           # abstract — Future<List<RoleWithCounts>> listRoles(); Future<RoleDetail> loadRoleDetail(roleId); Future<RoleMutationResult> mutateRole(MutateRoleParams); Future<void> deleteRole(roleId, expectedUpdatedAt);
│       │   │   └── user_search_repository.dart            # abstract — Future<List<UserSearchResult>> searchUsers(query); Future<List<AssignedRole>> loadUserAssignments(userId); Future<RoleAssignmentResult> assign(...); Future<void> revoke(...);
│       │   └── usecases/
│       │       ├── list_roles.dart
│       │       ├── load_role_detail.dart
│       │       ├── mutate_role.dart
│       │       ├── delete_role.dart
│       │       ├── search_users.dart
│       │       ├── load_user_assignments.dart
│       │       ├── assign_role_to_user.dart
│       │       └── revoke_role_from_user.dart
│       └── presentation/
│           ├── bloc/
│           │   ├── roles_list_bloc.dart                   # Loads, refreshes the roles list. Subscribes to nothing in v1 (Realtime is Phase 22).
│           │   ├── role_editor_bloc.dart                  # Captures expectedUpdatedAt on open. Tracks unsaved display_name JSONB / description / permission_keys delta. Save dispatches mutate_role use case; reacts to the 40001 / 42501 structured error codes by reloading and surfacing a localized message.
│           │   └── assign_role_bloc.dart                  # Debounced search. Per-user drawer state. Two-step super_admin grant confirmation. Single-step grant for other roles. Revoke confirmation. Hides the remove affordance on the super_admin's own super_admin row (Clarifications Q2 — UI half of the defense).
│           ├── pages/
│           │   ├── roles_list_page.dart                   # Shows the role catalog; system rows badged; non-system rows show a delete affordance; tapping a row opens RoleEditorPage; a Create button (gated by rolesCreate) opens CreateRolePage.
│           │   ├── role_editor_page.dart                  # Renders display_name inputs (ar + en), description, category-grouped permission checklist (read-only when role.key = 'super_admin' — Clarifications Q5); Save dispatches the RoleEditorBloc.
│           │   ├── create_role_page.dart                  # Form for new custom role (key, display_name ar+en, description, initial permission set); duplicate-key error mapped to a localized message.
│           │   └── assign_role_page.dart                  # Search input; result list; per-user role-management drawer; two-step super_admin grant flow with consequences dialog + typed-phone-or-username match; standard single-step grant for other roles; revoke confirmation with the count of users affected for role deletes (US4 acceptance 4).
│           └── widgets/
│               ├── role_card.dart
│               ├── permission_checklist.dart
│               ├── permission_category_header.dart        # Reads AppLocalizations.of(context).permissionCategory<Capitalized> per Clarifications Q6.
│               ├── confirmation_dialog.dart
│               ├── super_admin_grant_confirmation_dialog.dart # The two-step gate (consequences acknowledgement + typed match).
│               ├── assigned_role_row.dart
│               └── user_search_field.dart
└── shared/                                                # NO CHANGE.

lib/l10n/                                                  # (existing — Phase 3)
├── app_ar.arb                                             # UPDATE — add the 12 permissionCategory<Capitalized> keys + ~25 page/button/dialog/validation strings + structured-error-code→user-message map. All in Arabic.
└── app_en.arb                                             # UPDATE — same key set, English values.

CLAUDE.md                                                  # (existing — repo root)
                                                            # UPDATE — replace the SPECKIT START/END block to reference specs/007-super-admin-roles/plan.md (active spec is now 007). The /speckit-plan agent context update step performs this.

# Out of scope — explicitly NOT created in this phase:
# - lib/features/super_admin/permission_management/         — the v1 permission catalog is closed; no UI for creating new permission keys (Phase 6 assumption preserved).
# - supabase/functions/mutate_role/                         — Edge Function path deferred per Clarifications Q3.
# - test/**                                                 — durable no-new-tests rule. Existing Phase 1–6 tests remain unchanged.
# - .github/workflows/ci.yml                                — no new CI step.
# - new packages in pubspec.yaml                            — none.
# - lint guard extension for forbidden hardcoded role checks — Constitution VII enforcement is via PR review in Phase 7; the Phase 3 lint-guard extension remains optional (Phase 6 R-21 carried forward).
# - lib/features/admin/users/**                             — user-management surface (suspend / un-suspend / role assignment beyond the super-admin-only AssignRolePage) lands in a later phase.
# - Real-time permission propagation                        — Phase 22 owns push + Realtime. Phase 7 inherits Phase 6's three-point cache refresh unchanged; Phase 22 spec is tagged to revisit (project memory project_phase22_perm_cache_revisit.md).
# - First super_admin bootstrap migration                   — Per Phase 6 Q1 / Phase 7 entry condition, the first super_admin is created post-Phase-6 via privileged SQL. No Phase 7 migration assigns super_admin to anyone.
```

**Structure Decision**: Phase 7's footprint is balanced — five new SQL migrations + three new policy files + four doc updates on the backend; the first new feature folder of the post-Phase-6 era (`lib/features/super_admin/` with the full three-layer split) + a 2-line constants extension + ~37 ARB-key additions on the frontend. Phase 6's `AdminHomePage` gains one new tile; Phase 6's `permission_keys.dart` gains one new constant; no Phase 6 policy file is edited (the new write-side policies live in new files). The five-migration scheme consolidates the audit-trigger groups into one migration (per-table groups bundled) and the write-policy files into one migration (parallel to the three-file source-of-truth), consistent with Phase 6's R-02 inline-policy-bundling convention. The `mutate_role` SECURITY DEFINER RPC (Clarifications Q3) is the canonical atomic mutation entry point; the two assignment RPCs handle the user-role-grant paths with the two-step super_admin confirmation and unconditional self-revoke block (Clarifications Q1 + Q2) enforced server-side as defense-in-depth on top of the UI gating. The Edge Function path named in `docs/IMPLEMENTATION_PLAN.md §Phase 7` is deferred; the deviation is recorded in `spec.md` Clarifications, Constitution Check Note, and Assumptions per Constitution XII.

## Complexity Tracking

> No Constitution Check violations. This section is intentionally empty.
