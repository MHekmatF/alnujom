# Research: Super-Admin Role & Permission Management

**Owner**: Phase 7 (`specs/007-super-admin-roles/`).
**Status**: Locked at plan time (2026-05-15). All 22 decisions are binding for `/speckit-tasks` and `/speckit-implement`.

This document captures every technical decision the Phase 7 implementation MUST honor. Decisions are numbered R-01..R-22 and are referenced from `plan.md`, `data-model.md`, `contracts/*.md`, and `quickstart.md`. When a future spec needs to revisit one of these decisions, it updates the relevant `R-NN` here and links the new spec.

---

## R-01 — Migration filename convention (carry forward from Phase 4 R-01 → Phase 5 R-01 → Phase 6 R-01)

**Decision**: Phase 7's five new SQL migrations use synthetic-monotonic 14-digit timestamps `20260516120001` through `20260516120005`, applied via Supabase MCP `apply_migration` against the **remote** Supabase project. No local Supabase setup; no `supabase db reset` workflow. The migration tracker is the remote project's `supabase_migrations.schema_migrations` table.

**Rationale**: Phase 4 established the convention; Phases 5 and 6 carried it forward without deviation. Phase 7 is one day after Phase 6's `20260515` block — `20260516` is the natural next-day prefix. The five `120001..120005` suffix continues Phase 6's `120001..120008` convention (a `12hhmm`-style synthetic mid-day suffix that leaves room for future intra-day amendments without colliding).

**Alternatives considered**:
- Use the literal current UTC timestamp: rejected because the migrations are authored in a session and the literal moment-of-author isn't operationally meaningful; the monotonic prefix is what matters for ordering.
- Use a Phase 4-style 4-digit ordering (`0001..0036`): rejected — Phase 4 deliberately moved to timestamp-prefixed filenames to avoid renumbering when older specs land late.

## R-02 — Inline policy bundling within migrations (carry forward from Phase 6 R-02)

**Decision**: Phase 7's write-side RLS policies are authored in three new policy files under `supabase/policies/` (the source of truth for the policy SQL) AND inline in `20260516120002_create_phase7_write_policies.sql` (the migration that applies them to the remote project). The two copies are bit-identical at PR review time; the reviewer cross-checks them.

**Rationale**: Phase 6 explicitly preserved this convention from Phase 4 — the source-controlled policy file is the project-side documentation; the inline-in-migration copy is what actually applies. Phase 7 follows the same pattern for the three new write-side policies.

**Alternatives considered**:
- Apply policies only via the migration, with no parallel `supabase/policies/*.sql` files: rejected — Phase 4 and Phase 6 both maintain the parallel files for documentation grep-ability and for reviewers to read in isolation without flipping through migration history.
- Apply policies only via `supabase/policies/*.sql` loaded with `\i` from the migration: rejected — Supabase MCP `apply_migration` does not support `\i` (it expects a self-contained SQL body); inline duplication is the cost of the source-of-truth-plus-applied pattern.

## R-03 — First super_admin bootstrap is a Phase 7 deploy prerequisite (carry forward from Phase 6 R-16, Option C)

**Decision**: Phase 7 does NOT include a migration that assigns the `super_admin` role to any user. The first super_admin in the project lifetime is created via post-Phase-6 privileged SQL: `INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at) SELECT '<chosen-uuid>', id, NULL, now() FROM public.roles WHERE key='super_admin'` run via Supabase MCP `execute_sql` running as `postgres`. This is a one-time deploy action documented in `quickstart.md` as a Phase 7 entry condition. Every subsequent super_admin MAY follow either the in-app two-step grant path (R-04) or the same privileged-SQL recipe.

**Rationale**: Phase 6 explicitly closed this question with Option C (no Phase 6 migration assigns super_admin to a hand-picked UUID). Phase 7's super-admin UI is useful only once the first super_admin exists; the bootstrap is the bridge. Recording it as a deploy step rather than a migration preserves the "no hand-picked UUID lives in version control" invariant.

**Alternatives considered**:
- Phase 7 ships a migration that assigns super_admin to the project owner's UUID: rejected — the UUID would be hand-coded into a migration file, which (a) tightly couples the schema to a specific deployment, (b) makes the migration non-idempotent in a meaningful way (if the project owner's UUID changes for any reason, the migration produces a dead row), and (c) violates the spirit of "migrations describe schema, not data assignments to specific people".

## R-04 — Two-step super_admin in-app grant (Clarifications Q1 — Option C)

**Decision**: `AssignRolePage` allows granting `super_admin` to another user, gated by a two-step confirmation: (1) a consequences-dialog widget the super_admin must explicitly acknowledge ("this user will gain every permission in the catalog, including the ability to manage roles and permissions"); (2) a typed-confirmation field where the super_admin must type the target user's phone (E.164) or username; the grant button remains disabled until the typed value matches exactly. Both gates apply to the `super_admin` grant path only; every other role grant uses the standard single-step confirmation. The server-side `assign_role_to_user` RPC re-enforces the rule via a `confirmation_token` argument that must match `profiles.phone` or `profiles.username` for `target_user_id` when `target_role_id` references the `super_admin` row (defense-in-depth).

**Rationale**: Allows operational delegation (a super_admin can promote a colleague without DB access) while making accidental promotion meaningfully harder. The typed-match step is friction-proportional-to-blast-radius: super_admin is the highest-privilege role in v1; the friction is justified.

**Alternatives considered**:
- Option A — Allow in-app grants with the standard single-step confirmation: rejected — too easy to mis-tap.
- Option B — Block in-app grants entirely; every new super_admin requires the privileged-SQL bootstrap: rejected — operational friction whenever a new super_admin is needed; no in-app delegation path.

## R-05 — Unconditional super_admin self-revoke block (Clarifications Q2)

**Decision**: A super_admin can NEVER revoke their own `super_admin` role via `AssignRolePage` — regardless of how many other super_admins exist. The block is enforced in two places: (a) the UI hides the remove-affordance on the super_admin's own `super_admin` row; (b) the server-side `revoke_role_from_user` RPC raises `42501` with a structured error code when `target_role_id` references the `super_admin` row AND `auth.uid() = target_user_id`. To leave the super_admin role, a super_admin asks a different super_admin to revoke it. If the project ends up with zero super_admins (e.g., the last super_admin's `auth.users` row is deleted), recovery follows the same privileged-SQL bootstrap as R-03.

**Rationale**: Simplest mental model (one equality check); no count query in the critical path; defense-in-depth at the UI and server layers; preserves the "last super_admin cannot lock themselves out" invariant without requiring a `count(*) WHERE key='super_admin'` query on every revoke.

**Alternatives considered**:
- Option A — Block self-revocation only when last super_admin (count-aware guard): rejected — adds a count query to every revoke for marginal benefit; the simpler unconditional rule covers the same operational outcome.
- Option B — Allow self-revocation freely; recovery via the bootstrap recipe: rejected — invites accidental lockout; the recovery is not zero-cost.

## R-06 — SECURITY DEFINER SQL RPC, not Edge Function (Clarifications Q3)

**Decision**: The atomic role+permissions mutation entry point is a Postgres function `public.mutate_role(...)` defined `LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=public,auth`, applied via Supabase MCP `apply_migration`. The Edge Function path named in `docs/IMPLEMENTATION_PLAN.md §Phase 7` is **deferred** to a later phase that genuinely needs Edge Function infrastructure for a non-database reason (e.g., the Phase 22 FCM fan-out reading Vault secrets). The two assignment RPCs (`assign_role_to_user`, `revoke_role_from_user`) follow the same SECURITY DEFINER SQL pattern.

**Rationale**: Matches the project's established "no local Supabase setup" rhythm — every prior phase used Supabase MCP `apply_migration` exclusively, no `supabase functions deploy` flow has been exercised. Transactional atomicity is native to Postgres functions (the implicit `BEGIN ... COMMIT` envelope). Permission re-check is a one-line SQL guard (`IF NOT current_user_has_permission(...) THEN RAISE ...`). Audit-trail emission is on-table-trigger (already in place from FR-001/FR-002 + Phase 6's `user_roles` triggers). Edge Function deployment infrastructure (Supabase CLI deploy, service-role-key environment handling, separate observability surfaces) is meaningful new infrastructure that Phase 7 doesn't need.

**Deviation note** (Constitution XII): The implementation plan explicitly named `mutate_role` as an Edge Function. This research item records the deviation; the plan's parenthetical "Direct SQL also allowed via roles.create RLS, but the Edge Function exists to bundle the role-permission delta atomically" sentence acknowledged the direct-SQL path is permitted. The RPC delivers the same atomicity guarantee the Edge Function was named for.

**Alternatives considered**:
- Edge Function `mutate_role` matching the implementation plan literally: rejected — new deployment infrastructure for a problem Postgres solves directly.
- Ship both, client picks per operation: rejected — duplicate maintenance surface; no value-add.

## R-07 — Optimistic locking via existing `roles.updated_at` (Clarifications Q4)

**Decision**: Concurrent edits to the same `roles` row from two `RoleEditorPage` sessions are mediated by optimistic locking using the existing Phase 6 `roles.updated_at TIMESTAMPTZ` column (maintained by the Phase 4 `set_updated_at` trigger). The Flutter client captures `roles.updated_at` at the moment `RoleEditorPage` opens and passes it as the `expected_updated_at` argument to `mutate_role`. The RPC compares `expected_updated_at` against the stored `roles.updated_at` before any mutation; on mismatch, it raises `SQLSTATE 40001` (`serialization_failure`) with a structured error code; no partial writes happen. The UI catches the error, shows the localized "this role was changed by another super_admin — reload and re-apply your edits" message, drops the pending edits, and reloads the role from the live state.

**Rationale**: Phase 6 already created the `roles.updated_at` column with a trigger; Phase 7 leans on it for zero schema cost. Optimistic locking matches the actual operational pattern (rare super-admin concurrency on the same role) better than pessimistic locking (which would require an advisory-lock RPC and orphan-release handling). Last-write-wins (silent overwrite) was rejected because the surface is the most security-sensitive in v1; silent loss of a concurrent super_admin's edits would be unrecoverable absent audit-log archeology.

**Alternatives considered**:
- Last-write-wins: rejected per above.
- Pessimistic locking via advisory locks: rejected — orphan-lock handling adds complexity for marginal benefit at MVP scale.
- Defer concurrency handling to Phase 24: rejected — the cost of adding the guard now is one RPC parameter plus one `IF` clause; the risk of deferring is silent data loss in v1.

## R-08 — `super_admin` role permission mapping is immutable through Phase 7 surfaces (Clarifications Q5)

**Decision**: `RoleEditorPage` renders the permission checklist as read-only (disabled) when the active role's `key` is `super_admin`. The `display_name` and `description` fields remain editable on the same page so super_admin can localize labels (e.g., add a French translation). The `mutate_role` RPC additionally enforces the rule server-side: when `op='update'` AND `role_id` references the `super_admin` row AND the supplied `permission_keys` array differs from the role's current permission set, the RPC raises `42501` with a structured error code. The DB-side `role_permissions` table is NOT trigger-locked — the constraint is enforced by the RPC alone (a future spec MAY relax this via a different SECURITY DEFINER helper if needed).

**Rationale**: super_admin's identity-as-superuser depends on holding the full catalog (FR-006 Phase 6 seed). Emptying the permission set would render every super_admin inert with no in-app recovery path. The two-layer enforcement (UI hides the checklist; RPC rejects the write) is sufficient defense-in-depth for v1; deeper protection (a `BEFORE INSERT/DELETE ON role_permissions` trigger that raises when `role_id` references super_admin) is unnecessary because the only Phase 7 mutation surface for `role_permissions` is `mutate_role`.

**Alternatives considered**:
- Option A — DB-level trigger blocking any `role_permissions` INSERT/DELETE on the super_admin role: rejected — overkill; the surface area for direct-SQL super_admin mutation is bounded (only super_admins can write to `role_permissions` per FR-005, and they go through `mutate_role`).
- Option C — Allow freely with a stern warning: rejected — accidental disempowerment is recoverable only via the privileged-SQL bootstrap; the cost of the rule is two checks (UI + RPC) for permanent footgun elimination.
- Option D — Same warning as other system roles: rejected per same reasoning as Option C.

## R-09 — Permission-category headings localized via ARB keys (Clarifications Q6)

**Decision**: Phase 7's `RoleEditorPage` and `CreateRolePage` group the permission checklist by `permissions.category` (the Phase 6 TEXT column carrying values like `users`, `listings`, `roles`, `locations`, etc.). The category headings are rendered via 12 new ARB keys in both `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`:

- `permissionCategoryUsers` → "المستخدمون" / "Users"
- `permissionCategoryListings` → "العقارات" / "Listings"
- `permissionCategoryRoles` → "الأدوار" / "Roles"
- `permissionCategoryLocations` → "المواقع" / "Locations"
- `permissionCategoryCurrencies` → "العملات" / "Currencies"
- `permissionCategoryAds` → "الإعلانات" / "Ads"
- `permissionCategoryReports` → "البلاغات" / "Reports"
- `permissionCategoryAgencies` → "الوكالات" / "Agencies"
- `permissionCategorySettings` → "الإعدادات" / "Settings"
- `permissionCategoryAudit` → "سجل التدقيق" / "Audit log"
- `permissionCategoryInquiries` → "الاستفسارات" / "Inquiries"
- `permissionCategoryPermissions` → "الصلاحيات" / "Permissions"

The Phase 7 widget reads `permissions.category` (a stable TEXT identifier), normalizes it to the ARB key via a deterministic transform (e.g., `users` → `permissionCategoryUsers` — capitalize the first letter and prepend `permissionCategory`), and looks up the localized string via `AppLocalizations.of(context)`. If a future spec adds a new category and the corresponding ARB key is missing, the widget falls back to displaying the raw `category` value; the Phase 3 lint guard catches the missing-translation case at PR review.

**Rationale**: Matches Constitution V (every user-visible string flows through `AppLocalizations`); reuses the Phase 3 translation pipeline; no DB schema change. The `permissions.category TEXT` column from Phase 6 stays unchanged. Adding a new category in a future phase only adds new ARB entries; the data model doesn't need to evolve.

**Alternatives considered**:
- DB-side JSONB column on `permissions`: rejected — requires a Phase 7 schema migration on `permissions`; couples translation workflow to DB seed updates.
- Hand-maintained Dart constants in `permission_keys.dart`: rejected — bypasses the ARB pipeline (translators don't see the strings); breaks Constitution V.
- Show raw `category` value untranslated: rejected — would fail Constitution V at review.

## R-10 — Migration consolidation strategy

**Decision**: The five Phase 7 migrations are consolidated to match the project's per-concept granularity:

1. `20260516120001_create_phase7_audit_triggers.sql` — all three trigger groups in one migration (audit triggers are structurally identical across the three tables; combining keeps the migration count small).
2. `20260516120002_create_phase7_write_policies.sql` — all three write-side policy files inlined (parallel to the three new files under `supabase/policies/`).
3. `20260516120003_create_mutate_role_rpc.sql` — one RPC, one migration.
4. `20260516120004_create_user_role_assignment_rpcs.sql` — two RPCs (assign + revoke), one migration; they're peer functions with shared concerns.
5. `20260516120005_phase7_advisor_hardening.sql` — defense-in-depth REVOKE/GRANT pass.

**Rationale**: Five migrations mirror Phase 6's eight-migration scope at the same per-concept density. Combining the three audit-trigger groups (which share structure) and the three write-policy files (which share shape) keeps the migration list readable. The two assignment RPCs share dependencies (both call `current_user_has_permission('permissions.manage')`, both go through Phase 6's `user_roles` audit triggers) so one migration is appropriate.

**Alternatives considered**:
- Per-table audit-trigger migrations (3 separate files): rejected — too granular; the trigger functions are structurally identical except for the action key.
- Per-table write-policy migrations (3 separate files): rejected — same reasoning.
- One mega-migration: rejected — too coarse; per-concept rollback granularity is lost.

## R-11 — `mutate_role` RPC arguments shape

**Decision**: `mutate_role` accepts seven positional arguments: `op TEXT`, `role_id UUID`, `role_key TEXT`, `display_name JSONB`, `description TEXT`, `permission_keys TEXT[]`, `expected_updated_at TIMESTAMPTZ`. Returns `JSONB` carrying the resulting role row plus the applied permission keys. Unused arguments by `op` are passed as NULL (e.g., for `op='create'`, `role_id` and `expected_updated_at` are NULL; for `op='delete'`, `role_key`, `display_name`, `description`, `permission_keys` are NULL).

**Rationale**: Positional arguments work with Supabase RPC calls from `supabase_flutter` (`supabase.rpc('mutate_role', params: {...})`). The shape is human-readable (each argument is typed). NULLs are explicit; the function's body distinguishes the three `op` values explicitly. A bundled JSONB-only payload was considered but rejected because Postgres typing on the individual arguments catches malformed payloads at parse time rather than at function-body parse time.

**Alternatives considered**:
- Single JSONB argument carrying all fields: rejected — loses type checking; arguments could be misnamed without compile-time detection.
- Three separate functions (`create_role`, `update_role`, `delete_role`): rejected — duplicates the permission re-check and audit-handling logic; the `op` discriminator inside one function is cleaner.

## R-12 — Audit trigger granularity: one row per mutation row

**Decision**: Each individual INSERT/UPDATE/DELETE row affected by Phase 7's mutation surface produces one `audit_logs` row via the Phase 4 / Phase 7 trigger functions. A single `mutate_role` call that adds 3 permissions and removes 1 produces 1 `role.updated` row + 3 `role_permission.granted` rows + 1 `role_permission.revoked` row (5 audit rows total), NOT one bundled row. The audit-trail granularity equals the trigger-firing granularity. This matches Phase 6's `user_roles` audit convention (one row per `user_roles` INSERT/DELETE).

**Rationale**: Triggers are AFTER-ROW; per-row firing is the natural granularity. The Phase 4 `log_audit` function is designed for this — it reads `OLD` and `NEW` at row scope. Aggregating audit rows by RPC call would require the RPC to call `log_audit` directly (instead of relying on table triggers), which would (a) couple the RPC body to the audit schema, and (b) break the on-table-trigger pattern that fires for direct-SQL callers as well as RPC callers.

**Alternatives considered**:
- One bundled audit row per RPC call: rejected — couples RPC to audit schema; misses direct-SQL mutations.
- One row per RPC call carrying the array of changes in `after_state`: rejected — same coupling problem.

## R-13 — User search affordance: phone (E.164 prefix-match) + username (ILIKE substring)

**Decision**: `AssignRolePage`'s search field accepts a free-text query that is matched against both `profiles.phone` (prefix-match — `phone LIKE query || '%'`) AND `profiles.username` (substring ILIKE — `username ILIKE '%' || query || '%'`). The two predicates are OR'ed. Results are capped server-side at 50 rows and ordered by username alphabetical. The cross-user `profiles` read is admitted by the Phase 6 `users.view`-gated policy (super_admin holds it via the full-catalog mapping).

**Rationale**: Phase 5 introduced phone-as-canonical-identifier and `username` as the secondary handle. Both are reasonable search affordances. Prefix-match on phone is faster than substring-match and matches the typical use case (the super_admin knows the leading country-code digits). Substring ILIKE on username matches the typical username-typo-fix-by-search use case. The 50-row cap prevents UI overload; the order-by-username keeps results stable.

**Alternatives considered**:
- Phone-only: rejected — usernames are often more memorable.
- Username-only: rejected — Syrian users often share phone numbers verbally rather than usernames.
- Fulltext search on `profiles.full_name`: rejected — names can be ambiguous (multiple users with similar full names); phone and username are unique per FR-001 Phase 4 schema.

## R-14 — RPC structured-error-code catalog

**Decision**: The three Phase 7 RPCs raise specific `SQLSTATE` codes paired with structured human-readable messages. The Flutter client pattern-matches the SQLSTATE and maps to a localized ARB key. The catalog:

| SQLSTATE | RPC | Raised when | Localized message ARB key |
|---|---|---|---|
| `42501` | `mutate_role` | Caller lacks `roles.create` / `roles.update` / `roles.delete` / `permissions.manage` | `errorRolePermissionDenied` |
| `42501` | `mutate_role` | super_admin permission set immutability violated (R-08) | `errorSuperAdminPermissionsImmutable` |
| `42501` | `mutate_role` | System-role immutability trigger fires on DELETE or `key` rename | `errorSystemRoleImmutable` |
| `40001` | `mutate_role` | Optimistic-lock conflict (R-07) | `errorRoleEditConflict` |
| `23503` | `mutate_role` | DELETE blocked by `user_roles.role_id ON DELETE RESTRICT` | `errorRoleHasUsers` |
| `23505` | `mutate_role` | Duplicate `roles.key` on create | `errorRoleKeyDuplicate` |
| `42501` | `assign_role_to_user` | Caller lacks `permissions.manage` | `errorAssignPermissionDenied` |
| `42501` | `assign_role_to_user` | super_admin grant confirmation_token mismatch (R-04) | `errorSuperAdminGrantConfirmationFailed` |
| `23505` | `assign_role_to_user` | User already holds the role (UNIQUE conflict) | `errorUserAlreadyHoldsRole` |
| `42501` | `revoke_role_from_user` | Caller lacks `permissions.manage` | `errorRevokePermissionDenied` |
| `42501` | `revoke_role_from_user` | Self-revoke of super_admin attempted (R-05) | `errorSuperAdminSelfRevokeForbidden` |

The full table is also documented in `contracts/mutate-role-rpc.md`, `contracts/assign-role-to-user-rpc.md`, `contracts/revoke-role-from-user-rpc.md`.

**Rationale**: SQLSTATE is the Postgres-native error-channel; the Flutter client receives the value as `PostgrestException.code`. Standard SQLSTATEs (42501, 40001, 23503, 23505) cover the cases without inventing custom codes. The structured message text MUST be a stable identifier the client pattern-matches; the user-visible string comes from ARB.

**Alternatives considered**:
- All errors raised with `RAISE EXCEPTION 'custom message'` and pattern-match on the message string: rejected — string parsing is brittle; SQLSTATE is structured.
- Use a single `42501` for every Phase 7 error and rely on the structured message: rejected — distinct SQLSTATEs let the client take different actions (40001 means "reload"; 42501 means "you don't have permission"; 23505 means "user already has it"; etc.).

## R-15 — Super-admin entry point is a tile on the existing Phase 6 `AdminHomePage`

**Decision**: The Phase 7 super-admin surface is reached via a new tile "Super-admin" added to the Phase 6 `AdminHomePage`. The tile is visible iff `PermissionChecker.any(PermissionKeys.superAdminCategoryKeys)` returns `true`. Tapping it navigates to `/admin/super-admin/roles` (`RolesListPage`). The four super-admin routes (`/admin/super-admin/roles`, `/admin/super-admin/roles/:roleId`, `/admin/super-admin/roles/create`, `/admin/super-admin/assign`) are siblings of the existing Phase 6 admin routes.

**Rationale**: Matches the Phase 6 admin-home tile-listing pattern. Consolidates all admin-tier surfaces under a single home page (`/admin`). Adds zero new top-level navigation in the main app shell (the Phase 5 home page's admin tile is unchanged — it still navigates to `/admin`, which now contains both the account-approvals and the super-admin tiles).

**Alternatives considered**:
- Separate top-level "Super-admin" entry in the main navigation drawer: rejected — pollutes the navigation for the 99% of users who are not super-admins.
- Nested under a "Settings" or "Profile" page: rejected — semantically wrong; super-admin is not a personal-settings surface.

## R-16 — Permission-set delta computation is server-side in the RPC

**Decision**: When `mutate_role` is called with `op='update'` and a `permission_keys TEXT[]` array, the RPC computes the delta server-side by comparing the array against the current `SELECT array_agg(p.key) FROM role_permissions rp JOIN permissions p ON p.id=rp.permission_id WHERE rp.role_id = mutate_role.role_id`. Newly-included keys produce `INSERT` rows; newly-excluded keys produce `DELETE` rows. The client passes the full target set, not the delta; the server is the single source of truth for the "current" state.

**Rationale**: Client-supplied deltas are subject to TOCTOU race conditions (the client computed the delta against state A, but the server has state B by the time the call arrives). Server-side delta computation eliminates the race. The optimistic-lock check (R-07) handles the case where the client's view of state A is stale; together, the server has authoritative knowledge of both "what's there now" and "what should be there after this call".

**Alternatives considered**:
- Client computes delta and passes `add_keys`, `remove_keys` arrays: rejected — TOCTOU.
- Client passes the full set; server replaces the entire permission mapping (DELETE all + INSERT all): rejected — would emit N+M audit rows instead of N+M-overlap rows; the delta is the correct granularity for audit.

## R-17 — PermissionChecker cache refresh on grant uses Phase 6's three observation points unchanged

**Decision**: Phase 7 does NOT add a new observation point to the Phase 6 `PermissionChecker`. When a super_admin grants a role to a user via `AssignRolePage`, the affected user's permission cache refreshes via the three Phase 6 observation points: (1) auth-state listener events (token refresh on the next backend round-trip); (2) `WidgetsBindingObserver.didChangeAppLifecycleState(resumed)` on the next foreground; (3) the `AuthBloc._onAppResumedRefresh` handler. The spec's SC-011 verifies the observable behavior — the affected user's app shows the new tiles within a few seconds of foregrounding. Phase 22 (push + Realtime) is tagged to revisit (project memory `project_phase22_perm_cache_revisit.md`).

**Rationale**: Phase 6 deliberately left Realtime out of scope; Phase 7 is not the right place to introduce it. The three-point refresh is sufficient for the v1 use case (rare role changes; users typically foreground the app frequently).

**Alternatives considered**:
- Add a fourth observation point: Realtime subscription on `user_roles` for the affected user: rejected — Phase 22 territory.
- Force a sign-out / re-sign-in on the affected user's device after grant: rejected — too disruptive; not justifiable for a role change the user wants.

## R-18 — super_admin can be granted to oneself (silently): UNIQUE constraint blocks the duplicate

**Decision**: If a super_admin attempts to grant `super_admin` to themselves via `AssignRolePage`, the UI removes already-held roles from the role picker per US5 Acceptance Scenario 5; if the call somehow reaches the server, the `user_roles UNIQUE(user_id, role_id)` constraint causes either an `ON CONFLICT DO NOTHING` no-op (if the function uses that idiom) or a `23505` raised that the client maps to "user already holds this role". No special-case logic is needed in `assign_role_to_user`. The two-step confirmation gate (R-04) still fires before the call, but the no-op result is the safety net.

**Rationale**: The natural data model handles this case for free. No additional check is needed.

**Alternatives considered**:
- Explicit `IF auth.uid() = target_user_id AND target_role_id = super_admin.id THEN RAISE` self-grant block: rejected — unnecessary; granting oneself a role you already hold is a no-op, not a security issue.

## R-19 — Confirmation dialogs use a single reusable widget pattern

**Decision**: `lib/features/super_admin/presentation/widgets/confirmation_dialog.dart` is the reusable destructive-action confirmation widget. It accepts `title`, `body`, `confirmButtonLabel`, `cancelButtonLabel`, and `destructive: bool`. Used by: role delete (US4), user-role revoke (US5), bulk-revoke-then-delete (US4 acceptance scenario 4), and the standard side of any super_admin grant that is NOT a `super_admin` grant. The two-step `super_admin` grant uses a dedicated widget `super_admin_grant_confirmation_dialog.dart` that wraps the standard widget with the consequences-acknowledgement-plus-typed-match flow.

**Rationale**: One reusable widget keeps the look and feel consistent. The two-step `super_admin` grant is distinct enough to warrant its own widget (the typed-match input is a unique affordance).

**Alternatives considered**:
- Per-action confirmation dialogs: rejected — duplicates the widget; risks inconsistency.

## R-20 — Bulk operations are out of scope in v1

**Decision**: Phase 7 ships strictly one-role-at-a-time operations on `AssignRolePage`. No "grant this role to all selected users" affordance; no "revoke this role from all users" affordance (except the in-narrative "revoke and delete" path in US4 Acceptance Scenario 4, which is bulk-revoke implicit in delete-of-role with users-attached). The MVP scale (tens of users, single-digit super_admins) does not need bulk operations.

**Rationale**: Keeps the surface small in v1. Each grant/revoke is one audit row; bulk operations would emit bulk audit rows, which is fine, but the UX for "select multiple users and grant" requires a multi-select widget, batch-error handling, partial-success recovery — none of which is justified at MVP scale.

**Alternatives considered**:
- Ship multi-select grant: rejected — UX scope creep.

## R-21 — Phase 6 `agency_admin` 0-row permission mapping is preserved

**Decision**: Phase 7 does NOT add any permission rows to the `agency_admin` system role. The Phase 6 default (0 rows in `role_permissions` for `agency_admin`) is preserved; agency permissions land in Phase 19 (Agencies) with a future migration that INSERTs the appropriate rows. Super_admin can ADD permissions to `agency_admin` via `RoleEditorPage` in Phase 7 (the role's permission set is editable), but the Phase 7 deploy does not change the seeded mapping.

**Rationale**: Phase 6 assumption preserved. Phase 19 is the natural owner of the `agency_admin`-permission seed.

**Alternatives considered**:
- Phase 7 retroactively adds `agency_admin` permissions: rejected — speculative; the Phase 19 spec will define what `agency_admin` actually needs.

## R-22 — DEFERRED.md treatment

**Decision**: A `specs/007-super-admin-roles/DEFERRED.md` file is created during `/speckit-implement` if any intentional gap remains at squash-merge time. Per project memory `project_deferred_work.md`, the reviewer checks this file before squash-merge. If no gaps remain (the expected case), `DEFERRED.md` contains a single line: "No deferrals — Phase 7 ships complete." matching the Phase 6 pattern. Known deferral candidates: (a) the Edge Function path for `mutate_role` (Clarifications Q3, R-06 — deferred to a later phase that needs Edge Function infrastructure for a non-database reason); (b) Realtime cache refresh (Phase 22 — project memory `project_phase22_perm_cache_revisit.md`); (c) bulk operations on `AssignRolePage` (R-20 — explicitly out of scope in v1); (d) lint guard extension for forbidden hardcoded role checks (Phase 6 R-21 optional, carried forward as optional).

**Rationale**: Project convention preserves intentional-gap documentation as a closure check before merge.

**Alternatives considered**: none — this is a project convention, not a research decision.

---

## Cross-phase invariants carried forward (recorded for reference, not new decisions)

These were established by prior phases and continue to hold; Phase 7 does NOT modify them:

- **Phase 4 R-05 — Central-helper invariant**: Phase 4 / 5 / 6 policy files are NOT edited; helper bodies are swapped via `CREATE OR REPLACE FUNCTION`. Phase 7 introduces no body swap; new policies use the helpers as-is.
- **Phase 4 R-01 — Remote-Supabase migration apply**: every migration applies to the remote project via Supabase MCP `apply_migration`.
- **Phase 4 R-04 — `log_audit()` reusable trigger function**: unchanged for a third time (Phases 4/5/6/7 reuse it without modification).
- **Phase 5 R-12 / Phase 6 R-12 — Advisor-hardening pass**: every SECURITY DEFINER function has a follow-up `REVOKE EXECUTE FROM PUBLIC, anon` + explicit `GRANT EXECUTE TO authenticated` at the end of the phase's migration list.
- **Phase 6 R-15 — `user_roles` rows are immutable post-insert**: no UPDATE trigger or UPDATE policy on `user_roles` in Phase 7.
- **Phase 6 R-19 — Hand-maintained `permission_keys.dart`**: Phase 7 extends but does not codegen.
- **Phase 6 R-20 — Audit action-key convention**: full action key passed verbatim as `TG_ARGV[0]`; no TG_OP-derived verb appended.
- **Phase 6 R-21 — Lint guard optional**: Phase 7 PR review enforces Constitution VII; an automated lint guard remains optional and ships only if cheap.
- **`feedback_no_new_tests.md`**: Phase 7 ships zero new automated tests.
- **`feedback_git_workflow.md`**: Phase 7 PR is one squash-merged PR per spec; branch is `007-super-admin-roles`; merge target is `main`.
- **`project_dart_defines.md`**: every Flutter run/build for Phase 7 verification includes `--dart-define-from-file=.env.json`.
- **`project_supabase_mcp_apply_migration.md`**: every Phase 7 migration is idempotent (`CREATE OR REPLACE`, `DROP IF EXISTS ... CREATE`, etc.) so re-application via `apply_migration` doesn't accumulate duplicates.
- **`project_phase22_perm_cache_revisit.md`**: Phase 22 spec MUST re-evaluate the Phase 6 three-point cache refresh in light of Phase 7's additional mutation surface.
- **`project_deferred_work.md`**: `DEFERRED.md` is the closure check before squash-merge.
