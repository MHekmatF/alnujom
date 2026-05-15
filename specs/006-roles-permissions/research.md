# Phase 6 — Roles & Permissions: Research

Locked technical decisions for `specs/006-roles-permissions/`. Each entry records: **Decision** / **Rationale** / **Alternatives considered**. Every `[NEEDS CLARIFICATION]` from the spec has been resolved by Session 2026-05-15 (see `spec.md` → `## Clarifications`); this document captures the broader technical choices that don't rise to spec-level clarifications but still need a single source of truth for `/speckit-implement` to follow.

The numbering continues the spec-005 R-NN convention.

---

## R-01 — Migration filename convention and ordering

**Decision**: Phase 6's eight migrations are named with synthetic-monotonic 14-digit timestamps starting at `20260515120001` and ending at `20260515120008`, ordered after Phase 5's last migration `20260510120006_phase5_advisor_hardening.sql`. The implementation plan's `0007_create_roles.sql` ... `0010_create_user_roles.sql` filename hints are HISTORICAL — superseded by the timestamp convention locked in Phase 4 (R-02) and continued by Phase 5 (R-01). The eight files:

1. `20260515120001_create_roles.sql`
2. `20260515120002_create_permissions.sql`
3. `20260515120003_create_role_permissions.sql`
4. `20260515120004_create_user_roles.sql`
5. `20260515120005_create_permission_predicate.sql`
6. `20260515120006_swap_admin_predicate_to_role_check.sql`
7. `20260515120007_backfill_is_admin_and_drop.sql`
8. `20260515120008_phase6_advisor_hardening.sql`

**Rationale**: Timestamps preserve global ordering across phases without coordination — Phase 4 used them, Phase 5 used them, Phase 6 continues. Migration 5 (helper function) depends on tables from migrations 1–4; migration 6 (body swap) is an isolated `CREATE OR REPLACE`; migration 7 (backfill + drop) depends on tables from migrations 1 + 4 and uses the helper from migration 6 to verify post-conditions; migration 8 hardens 5 + 6 + 4's trigger function. The order is forced by these dependencies.

**Alternatives considered**:
- Phase-counter prefixes (`0007_*` ... `0014_*` per the implementation-plan hints). REJECTED for the same reasons Phase 4 R-02 / Phase 5 R-01 rejected them: collisions between concurrent feature branches; no global temporal ordering; superseded by the timestamp convention already in use.
- Squashing migrations 1–4 into a single multi-table migration. REJECTED: harder to read, harder to roll back conceptually, harder to attribute audit/get_advisors warnings to the right table; the eight-file split mirrors Phase 5's "one migration per concrete artifact" pattern.
- Squashing migrations 5 (`current_user_has_permission`) and 6 (`current_user_is_admin` body swap) into one. REJECTED: the two helpers have different concerns — the new helper is fresh; the body swap is a Phase-5-amendment that must be auditable as a separate change in `git log` and `git blame`.

---

## R-02 — Migration apply mechanism

**Decision**: Apply every Phase 6 migration to the **remote** Supabase project via Supabase MCP `apply_migration`. No local Supabase environment is established in Phase 6.

**Rationale**: Inherited from Phase 4 R-01 and preserved by Phase 5. The project has no local Supabase setup; the Supabase MCP is the canonical migration-apply mechanism. Per project memory `project_supabase_mcp_apply_migration.md`, re-applying an existing migration name re-runs the SQL AND adds a duplicate tracker row — so every migration body is idempotent (`CREATE TABLE IF NOT EXISTS`, `INSERT ... ON CONFLICT (key) DO NOTHING`, `CREATE OR REPLACE FUNCTION`, `DROP TRIGGER IF EXISTS … CREATE TRIGGER`, `ALTER TABLE … DROP COLUMN IF EXISTS`).

**Alternatives considered**:
- Setting up a local Supabase environment for this phase. REJECTED: a structural change that crosses spec boundaries (would impact every prior and future phase); not in scope for Phase 6.
- Using `psql` directly against the remote project's connection string. REJECTED: bypasses the Supabase MCP, which provides migration tracking and consistency.

---

## R-03 — Seed location: inline in create-table migrations vs. separate seed files

**Decision**: The seed for `roles` (7 system rows), `permissions` (24 keys), and `role_permissions` (the §9.1 default mappings) lives **inline** in the three create-table migrations (`20260515120001_create_roles.sql`, `20260515120002_create_permissions.sql`, `20260515120003_create_role_permissions.sql`) — each as the last block after `CREATE TABLE` + `ENABLE RLS` + policy creation. Each `INSERT` uses `ON CONFLICT (key) DO NOTHING` so the seed is idempotent.

**Rationale**: Atomicity — the table exists with its catalog populated in a single migration. Re-apply safety — `ON CONFLICT DO NOTHING` makes re-runs a no-op for the seed. The `supabase/seed.sql` file at the repo root (existing since Phase 1) is the right home for *demo* data; the §9.1 catalog is a *schema invariant* (every deploy of this app has these 24 permission keys, full stop), not demo data — so inlining it in the migration is the correct treatment. Phase 4 set the precedent with the `account_status` / `publisher_status` enums being declared inline with their owning table.

**Alternatives considered**:
- A separate `supabase/seed/role_permissions.sql` file applied after the migrations. REJECTED: introduces a two-step apply (migration + seed); the catalog is a schema invariant, not demo data; the inline approach is more atomic.
- Hand-writing the §9.1 catalog into `supabase/seed.sql` (the existing root seed). REJECTED: `supabase/seed.sql` is for project-wide demo data; mixing schema-invariant catalog with demo data couples two unrelated concerns.

---

## R-04 — Admin role permission count: §9.1 says 15 + agencies.view + inquiries.view_all = 16 rows for the admin role

**Decision**: The seeded `admin` role's `role_permissions` mapping has **16 rows**, not the literal 15 implied by §9.1's bullet ("the moderator perms + agencies.approve + agencies.suspend + ads.manage + audit_logs.view + currencies.manage + listings.edit_any + locations.manage + users.approve + users.reject + users.suspend" = 5 + 10 = 15 rows). Phase 6's seed adds `agencies.view` and `inquiries.view_all` to admin, bringing the total to 16. The justification: admins observably need `agencies.view` to see what `agencies.approve` is for (the approve action without the view permission is a UX dead-end); and admins need `inquiries.view_all` because the implementation plan's §9.1 lists it as a cross-publisher visibility perm and there is no role above admin (other than super_admin) — without admin holding it, only super_admin would ever see cross-publisher inquiries, which is too narrow.

**Rationale**: §9.1's literal bullet for admin omits these two because the bullet was written as "moderator perms + admin-only writes" — `agencies.view` is technically also a moderator-visible read in spirit, and `inquiries.view_all` was listed standalone. Phase 6's seed reads §9.1 as a list of intent ("admins have everything in their categories that the moderator has plus their writes"), not as a literal enumeration. Constitution XII (No Hidden Product Decisions) requires this be documented — it's documented here.

**Alternatives considered**:
- Strictly seeding admin with exactly the 15 keys §9.1 lists. REJECTED: produces an inconsistent UX where admin can `agencies.approve` but cannot `agencies.view`; produces a security model where only super_admin sees cross-publisher inquiries even though admin holds every PII decrypt path through `current_user_is_admin()`.
- Adding ALL permissions to admin (effectively making admin == super_admin without the `roles.*` and `permissions.manage` and `listings.delete_any` keys). REJECTED: blurs the admin/super_admin distinction that §9.1 establishes. Super_admin is distinguished by: `roles.create`, `roles.update`, `roles.delete`, `permissions.manage`, `settings.manage`, `listings.delete_any`. Admin should NOT hold those.

**Final admin permission count**: 16. Specifically:
- From moderator (5): `users.view`, `listings.view_all`, `listings.approve`, `listings.reject`, `reports.manage`.
- From admin-only writes (9): `users.approve`, `users.reject`, `users.suspend`, `listings.edit_any`, `locations.manage`, `currencies.manage`, `ads.manage`, `agencies.approve`, `agencies.suspend`.
- From admin-required reads (2): `agencies.view`, `inquiries.view_all`.
- Total: 5 + 9 + 2 = **16**.

---

## R-05 — Central-helper invariant preservation (Phase 4 R-05 carried forward)

**Decision**: No Phase 4 or Phase 5 policy file is edited in Phase 6. The `current_user_is_admin()` helper's body is swapped via `CREATE OR REPLACE FUNCTION` in `20260515120006_swap_admin_predicate_to_role_check.sql`; every existing policy that referenced the helper by name picks up the new behavior automatically. This preserves Phase 4 R-05's central-helper invariant a second time (Phase 5 R-12 preserved it once already).

**Rationale**: Editing policy files in successor phases would (a) increase merge conflict risk; (b) make `git blame` confusing for who-shipped-what; (c) require Phase 5's policy file edits to be re-reviewed during Phase 6's PR review; (d) violate the implicit contract that "every later phase's policy work is additive — new files, not edits." The body swap is a single function definition change; the swap migration is atomic at apply time; the new behavior is "user holds `admin` or `super_admin` role" which is a strict superset of "user holds `admin` role" if super_admin is unassigned (Q1 — Option C ships zero super_admins; only admin holds the role at Phase 6 deploy time).

**Alternatives considered**:
- Edit `account_approval_requests_policies.sql` (Phase 5) to gate by `current_user_has_permission('users.approve')` directly. REJECTED: violates the invariant; moves the gating logic from one well-known location (the central helper) to a scattered set of policy files; makes future re-gating (e.g., adding a "moderator can approve some accounts" path) require touching every relevant policy file rather than just the central helper.
- Delete `current_user_is_admin()` entirely and refactor every Phase 4/5 policy. REJECTED: massive blast radius; Phase 5 ships seven policies that reference the helper; bulk policy-file edit is exactly what the invariant exists to prevent.

---

## R-06 — System-role immutability enforcement mechanism

**Decision**: Enforce system-role immutability via a `BEFORE UPDATE OR DELETE` trigger on the `roles` table (`enforce_role_system_immutability()`). The trigger raises `42501 insufficient_privilege` when the operation is DELETE on an `is_system=TRUE` row OR when the operation is UPDATE on an `is_system=TRUE` row that changes `key` (i.e., `OLD.is_system AND (TG_OP='DELETE' OR NEW.key IS DISTINCT FROM OLD.key)`). The `display_name` and `description` columns ARE editable even for system rows.

**Rationale**: A trigger is the only enforcement mechanism that fires uniformly across (a) RLS-bypassed callers (the `postgres` role), (b) future Phase 7 super-admin UI updates, and (c) any direct SQL run via Supabase MCP `execute_sql`. A CHECK constraint cannot reference `OLD.*` so it can't distinguish "this is a system row being deleted" from "this row was inserted with `is_system=true`". An RLS-side guard would only fire for non-privileged callers — but the privileged caller is exactly who Phase 7 will be (super_admin acting via SECURITY DEFINER RPCs); we need the guard there too. The trigger is also auditable in `pg_trigger`.

**Alternatives considered**:
- A CHECK constraint `CHECK (NOT is_system OR …)`. REJECTED: cannot reference `OLD.*`; cannot enforce "you can't delete a system row" since DELETE doesn't go through CHECK.
- An RLS UPDATE/DELETE policy gated by `NOT EXISTS (SELECT 1 FROM roles WHERE id = NEW.id AND is_system=TRUE)`. REJECTED: RLS is bypassed by `postgres`; Phase 7's super-admin RPCs will be `SECURITY DEFINER` which bypasses RLS — exactly the scenarios where we still want the immutability check to fire.
- A `SECURITY DEFINER` function for all role mutations + revoke direct UPDATE/DELETE. REJECTED: more code surface; doesn't match the inline-migration pattern; harder for Phase 7's super-admin UI to invoke (would need a wrapper function for every legal field combination).

---

## R-07 — Permission key source of truth on the Flutter side

**Decision**: Hand-maintained Dart constants in `lib/core/security/permission_keys.dart`. The file is the canonical Flutter-side mirror of the seeded `permissions.key` values. The class layout is `class PermissionKeys` with `static const String fieldName = 'category.action'` — one field per seeded permission, organized by category sections via dartdoc comments. The class is `abstract` to prevent instantiation. Pairing: whenever a future spec adds or removes a permission key via migration, the same PR MUST update `permission_keys.dart` to match.

**Rationale**: Codegen from the seeded table would be ideal but adds tooling complexity (a build-runner step or a script that polls Supabase) that's not justified at v1 scale (24 keys, low rate of change). Hand-maintained constants give compile-time safety on the Flutter side and a single grep target for "every place that uses `users.approve`." The PR-review pairing rule prevents drift.

**Alternatives considered**:
- String literals everywhere (`permissionChecker.has('users.approve')`). REJECTED: typo-prone, no compile-time check, harder to refactor.
- An enum (`enum PermissionKey { usersApprove, usersReject, ... }`). REJECTED: requires a String-mapping table; the dot-namespaced keys (`users.approve`) don't map cleanly to enum value names; the value the SQL helper expects IS the dot-namespaced string, so the enum would just be a wrapper that does `enum.toKeyString()`.
- Codegen from the seeded `permissions` table at build time. REJECTED for v1 (deferred to a future spec); acceptable to revisit when the catalog grows beyond ~50 keys or when the rate of change increases.

---

## R-08 — PermissionChecker cache shape

**Decision**: The `PermissionChecker` caches the signed-in user's effective permission set as a `Set<String>` (the set of permission keys). The cache is a private field of the singleton; access is via `has(String)` / `any(Iterable<String>)` / `all(Iterable<String>)` synchronous methods. The cache is initialized to empty on construction; `load()` populates it; `refresh()` re-populates it atomically (the new set replaces the old at the end of the round-trip — never partially); `clear()` resets it to empty.

**Rationale**: `Set<String>` is the simplest correct shape for "does the user have key X" lookups (O(1) hash). Phase 6 needs no metadata beyond presence/absence — the seeded `description` / `category` columns are for the future Phase 7 super-admin UI, not for runtime permission checks. The atomic replace on `refresh()` (don't mutate the existing set; build a new one and assign at the end) prevents widget rebuilds from seeing a half-loaded cache.

**Alternatives considered**:
- A more structured `Map<String /* category */, Set<String> /* keys */>`. REJECTED: no Phase 6 surface needs to enumerate by category; categories are a Phase 7 super-admin-UI grouping concept, not a runtime check. A simple Set is enough.
- A `List<PermissionEntity>` where each entity carries key + category + description. REJECTED: over-engineered for the FR-014 contract; the entity would be a wrapper over a String for no runtime benefit.
- Caching at the role level (`Set<RoleEntity> roles`) and computing the effective permission set on every `has()` call. REJECTED: more code; permission joins happen at the data-source boundary anyway; the runtime side should just see a flat set.

---

## R-09 — PermissionChecker DI registration and lifetime

**Decision**: `PermissionChecker` is registered as a **lazy singleton** via Phase 1's existing `injectable` + `build_runner` codegen flow — annotate `PermissionChecker` with `@lazySingleton` and `PermissionCatalogRepositoryImpl` with `@LazySingleton(as: PermissionCatalogRepository)`. The regenerated `lib/core/di/injection.config.dart` produces `gh.lazySingleton<PermissionChecker>(() => PermissionChecker(gh<PermissionCatalogRepository>()))` and `gh.lazySingleton<PermissionCatalogRepository>(() => PermissionCatalogRepositoryImpl())` — the impl takes no constructor args because it uses `Supabase.instance.client` directly (Phase 5 data-layer pattern), NOT a `SupabaseClientWrapper` injection (the wrapper is consumed by Phase 5's `SupabaseAuthDataSource` via its own DI path; the Phase 6 repository does not need it). The singleton lives for the whole app lifetime; `clear()` is called on sign-out (NOT a re-construction — the singleton survives; only its cache is cleared).

**Rationale**: Singleton scope is correct because the PermissionChecker is session-scoped state that needs to be readable from ANY widget without an InheritedWidget cascade — the same pattern as `SupabaseClientWrapper`. Lazy registration avoids the cost of a `loadEffectivePermissions()` round-trip until a widget actually consults `has(...)` for the first time. The `clear()`-on-sign-out approach (rather than re-registering the singleton) means widgets that hold a reference to the singleton continue to work without re-resolving from `getIt`.

**Alternatives considered**:
- Cubit/BLoC instead of a singleton. REJECTED: introduces widget-tree coupling (`BlocProvider`, `context.read`) for what is a synchronous read-only API; the BLoC pattern shines for "events → state transitions," but PermissionChecker is just a cache.
- Provider/Riverpod. REJECTED: introduces a new state-management dependency the project hasn't adopted; Constitution IV says BLoC/Cubit defaults; this is an exception that uses raw `get_it` because the API is closer to a service than a state machine.
- A factory instead of a singleton. REJECTED: every `has()` call would resolve a new instance with an empty cache; defeats the caching purpose.

---

## R-10 — PermissionCatalogRepository data-layer call shape

**Decision**: The Supabase impl of `PermissionCatalogRepository.loadEffectivePermissions()` executes a single Postgrest request against `user_roles` with a nested select, then flattens the result on the client. Specifically: `supabase.from('user_roles').select('role:roles(role_permissions(permission:permissions(key)))').eq('user_id', authUid)`. The client maps the nested response into a `Set<String>` of `permission.key` values.

**Rationale**: A single round-trip; uses Postgrest's nested-resource embedding (the same shape Phase 5 used for `account_approval_requests` → `profiles`). The PostgreSQL planner converts the request to a series of joined SELECTs that RLS gates correctly (`user_roles` self-read admits the row; `role_permissions` and `permissions` are authenticated-read). Returns the data already shaped for the consuming client; client-side flattening is a fold over the JSON tree.

**Alternatives considered**:
- A `SECURITY DEFINER` RPC `get_my_effective_permissions()` returning `TEXT[]`. REJECTED: introduces an extra SQL artifact (one more migration), bypasses RLS, and gains nothing in v1 — the Postgrest nested select is just as fast for the seed-sized catalog. ADOPT in a future spec only if the join becomes a hotspot at scale.
- Three separate round-trips (fetch `user_roles`, fetch `role_permissions`, fetch `permissions`). REJECTED: 3x round-trip cost, harder to keep consistent, no compensating benefit.
- A Supabase View pre-joining the three tables. REJECTED: views need their own RLS or `SECURITY DEFINER` invocation, adds complexity, no clear benefit.

---

## R-11 — Backfill ordering and atomicity

**Decision**: The FR-011 backfill migration is a single transactional file (`20260515120007_backfill_is_admin_and_drop.sql`). The Supabase migration tool wraps each migration in an implicit transaction, so all five steps land atomically (any error rolls back). The ordering: (a) INSERT `admin` rows for prior `is_admin=true` users (idempotent via `ON CONFLICT (user_id, role_id) DO NOTHING`); (b) INSERT `user` rows for every existing `profiles` row (also idempotent); (c) `ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_admin`; (d) `CREATE OR REPLACE FUNCTION enforce_profile_status_admin_only()` with the `is_admin` reference removed. Step (a) MUST happen before step (c) — otherwise the `is_admin = TRUE` selector reads a dropped column. Step (b) MUST happen before step (c) — same reason, but step (b)'s selector doesn't reference `is_admin`, so it doesn't strictly depend on the column existing; ordering it before the drop is a documentation choice. Step (d) MUST happen after step (c) — the function body removes the `is_admin` reference; if step (d) ran before step (c), the function would still reference a (still-present) column, but post-step-(c) the function would error on every UPDATE of profiles, breaking the rest of the system.

**Rationale**: The single-migration approach is the simplest correct shape. Splitting into two migrations (backfill, then drop+function-update) introduces a brief window where the column exists with row counts in `user_roles` but no enforcement function update yet — at that point any client UPDATE of `profiles` would still go through the un-updated trigger (which still works because the column still exists), so the split is technically safe, but it complicates the migration tracker (two rows instead of one for "the is_admin transition"). The single migration is cleaner.

**Alternatives considered**:
- Two separate migrations: `20260515120007_backfill_admin_role.sql` (just the INSERTs) and `20260515120008_drop_is_admin_column.sql` (drop + function update). REJECTED: complicates the migration tracker; no operational benefit (the migration tool wraps each in its own transaction anyway; the two transactions are not coordinated).
- A SECURITY DEFINER function to do the backfill (invoked from the migration). REJECTED: over-engineered; the migration body has SECURITY DEFINER privileges in apply context anyway.
- Skipping step (b) — only inserting `admin` rows, leaving the implicit "every user has `user`" invariant to be picked up by the FR-013 trigger on future signups only. REJECTED: violates SC-005's invariant (every existing profile must hold a `user` role); a moderator (post-Phase-6) reading `user_roles` for an existing user would see only the `admin` row, not the implicit `user` baseline — a confusing data shape.

---

## R-12 — `current_user_is_admin()` body swap mechanism

**Decision**: A single `CREATE OR REPLACE FUNCTION public.current_user_is_admin() RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth AS $$ ... $$;` in `20260515120006_swap_admin_predicate_to_role_check.sql`. The new body wraps an EXISTS check in `COALESCE(..., FALSE)`:

```sql
SELECT COALESCE((
  EXISTS (
    SELECT 1
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid()
      AND r.key IN ('admin', 'super_admin')
  )
), FALSE)
```

The function's name, signature, return type, and qualifiers are unchanged from Phase 5's swap. No policy file is edited.

**Rationale**: Mirrors Phase 5's R-12 pattern exactly. The body swap is the central-helper invariant in action — every Phase 4 and Phase 5 policy that references `current_user_is_admin()` by name continues to work, with the new semantics being "user holds admin OR super_admin role." The `COALESCE(..., FALSE)` defensively handles the edge cases: callers without `auth.uid()` (service-role sessions, migrations) get FALSE without raising; the EXISTS already returns FALSE for empty result sets, so the COALESCE is a belt-and-suspenders guard against future SET-RETURNING changes.

**Alternatives considered**:
- Body changes to call `current_user_has_permission('admin')` (treating "admin" as a virtual permission key). REJECTED: `'admin'` is not in the §9.1 catalog; no row in `permissions` exists for it; introducing a fake key just to make the helper one-liner is confusing. The role-membership check is direct and clear.
- Drop `current_user_is_admin()` entirely and find/replace every Phase 4/5 policy reference with the new role-check expression. REJECTED: violates R-05 (central-helper invariant); large blast radius in policy files.
- Add a new helper `current_user_is_admin_or_super_admin()` and leave `current_user_is_admin()` returning the old behavior. REJECTED: requires editing every policy that referenced the old helper; defeats the central-helper invariant.

---

## R-13 — Cross-user `profiles` read policy stacking

**Decision**: Phase 6 ADDS a stacked SELECT policy on `profiles` named `profiles_phase6_users_view`: `FOR SELECT TO authenticated USING (current_user_has_permission('users.view'))`. This policy lives in a NEW file `supabase/policies/profiles_phase6_users_view.sql`. The existing Phase 4 self-only SELECT policy in `profiles_policies.sql` is NOT edited; PostgreSQL ORs together the USING expressions of multiple SELECT policies on the same table for the same role, so the effective grant is "self-read OR cross-user-read-with-users.view".

**Rationale**: Pure additive change; preserves R-05's no-Phase-4-policy-edits invariant; PostgreSQL's RLS semantics make policy stacking straightforward for SELECT — each policy is OR'd together. The new file lives next to its sibling policy files in `supabase/policies/`, keeping a flat directory. Naming follows the pattern `<table>_<phase>_<descriptor>.sql` so future stacked policies on the same table (Phase 8's `locations.manage`, etc.) can follow the same convention.

**Alternatives considered**:
- Modifying the Phase 4 `profiles_policies.sql` to add the new policy block. REJECTED: violates R-05.
- A single combined policy with `auth.uid() = user_id OR current_user_has_permission('users.view')`. REJECTED: would require either editing the Phase 4 policy file (R-05 violation) or removing the Phase 4 policy and re-creating it in a Phase 6 file (which is a Phase 4 policy edit by another name); the stacking-with-OR approach is the idiomatic Postgres RLS pattern for additive grants.
- A different policy name (e.g., `users_view_cross_read`). REJECTED: harder to grep for, doesn't carry the phase tag.

---

## R-14 — Auto-`user`-role trigger placement on `profiles INSERT`

**Decision**: Define `auto_create_user_role_for_user()` as `LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth` and attach as `AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION auto_create_user_role_for_user()`. Both the function and trigger live in `20260515120004_create_user_roles.sql` (the migration that creates `user_roles`). The function body: `INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at) VALUES (NEW.user_id, (SELECT id FROM public.roles WHERE key = 'user'), NULL, now()) ON CONFLICT (user_id, role_id) DO NOTHING;`. The trigger is created via `DROP TRIGGER IF EXISTS ... CREATE TRIGGER ...` for idempotency.

**Rationale**: AFTER INSERT (not BEFORE) because the new `profiles.user_id` value is what we read into `user_roles.user_id`; AFTER fires after the row is persisted, with `NEW` referring to the persisted row. `SECURITY DEFINER` because the trigger fires in the auth-side INSERT path (where `auth.uid()` is the new user's id, which has no `roles.update` permission to write to `user_roles` themselves); the function runs as the migration owner (postgres). `ON CONFLICT DO NOTHING` for idempotency — if Phase 4's auto-provision trigger somehow fires twice (unlikely but defensible), the second insert is a no-op.

**Alternatives considered**:
- Trigger on `auth.users` INSERT directly. REJECTED: Phase 4's auto-provision trigger already fires on `auth.users` insert to create the `profiles` row; chaining a second trigger there couples Phase 6 to Phase 4's trigger ordering. Triggering on `profiles` insert is cleaner — `profiles` is the public schema, owned by this project.
- A BEFORE INSERT trigger. REJECTED: `NEW.user_id` is set by the inserter, so AFTER vs. BEFORE makes no functional difference for the user_id lookup; AFTER is the more semantically correct event for "after this profile is durable, ensure the role assignment is also durable."
- Defer the auto-user-role insert to the next time `PermissionChecker.load()` is called by the new user's session. REJECTED: leaves the `user_roles` table inconsistent (the user exists but holds no role row until their first authenticated load); database invariants should be DB-side.

---

## R-15 — Audit triggers on `user_roles` (FR-010)

**Decision**: Attach **two separate triggers** to `user_roles` — `trg_user_roles_audit_granted` AFTER INSERT calling `log_audit('user_role.granted', '*', 'user_id')`, and `trg_user_roles_audit_revoked` AFTER DELETE calling `log_audit('user_role.revoked', '*', 'user_id')`. No UPDATE trigger in v1 (rows are immutable post-insert). The trigger creates use `DROP TRIGGER IF EXISTS … CREATE TRIGGER …` for idempotency. Both triggers live in `20260515120004_create_user_roles.sql`.

**Rationale**: Phase 4's `log_audit()` function (defined in `supabase/migrations/20260506120004_create_audit_logs.sql:24`) takes the action string **verbatim** from `TG_ARGV[0]` — it does NOT append a TG_OP-derived verb. Phase 5's convention (already in use for `account_approval_requests` and `profiles`) is to pass the full action key as the first argument. Phase 6 mirrors that convention with one trigger per legal event, each carrying its own action key. Targeting `user_id` (rather than the `user_roles.id` PK via the `'user_id'` third arg) means an admin reviewing audit logs for a specific user sees role-grant/revoke entries grouped under that user — the practical query shape. `'*'` for columns serializes the full row into `before_state`/`after_state` JSON — cheap because `user_roles` rows are small. Phase 4's R-05 reusability invariant is preserved — `log_audit` itself is unchanged.

**Alternatives considered**:
- **A single trigger with `AFTER INSERT OR UPDATE OR DELETE` and a generic action key like `'user_role.changed'`**. REJECTED: less informative — `audit_logs` grep for "user was granted admin" vs "user lost admin" becomes a two-step query (action='user_role.changed' AND join the before/after JSON for the role_id and TG_OP heuristic). Two triggers with distinct keys is the Phase 5 convention.
- **A single trigger passing `'user_role'` as the action key, expecting log_audit to append TG_OP**. REJECTED: this was the bug found in the initial Phase 6 design — `log_audit` does NOT append the verb. (Phase 6 analysis F1 caught this.)
- **Targeting `user_roles.id` instead of `user_id`**. REJECTED: the assignment's PK is not what an admin looks for in audit logs; the affected user is.
- **A custom per-row trigger function (not reusing `log_audit`)**. REJECTED: Phase 4 R-05 reusability invariant violated; more code surface.
- **Skipping audit on `user_roles` entirely until Phase 7**. REJECTED: the backfill migration itself is the first user-role mutation in the project's history; not auditing it would leave a permanent hole at the start of the audit log. The backfill migration's `actor_user_id` is NULL (it runs as `postgres` with no `auth.uid()`), distinguishable from in-app assignments.

---

## R-16 — First super_admin bootstrap (Q1 — Session 2026-05-15 clarification)

**Decision**: **Option C** — the Phase 6 backfill assigns nothing for super_admin. Every prior `is_admin=true` user becomes `admin` only. The first super_admin is created post-Phase-6 via privileged SQL (`Supabase MCP execute_sql` running as `postgres`). Mirrors the Phase 5 R-19 admin bootstrap pattern. Phase 7's super-admin UI requires this one-time privileged SQL action as an entry condition before it can function — documented as a Phase 7 deploy prerequisite, not a Phase 6 gap.

**Rationale**: Mirrors Phase 5's documented R-19 pattern, keeping operational consistency across phases. No hand-picked UUID lives in a checked-in migration file. The cost (one extra deploy step before Phase 7's super-admin UI works) is acceptable because Phase 7 has its own deploy that can encode the bootstrap SQL as a one-line operational task in that phase's `quickstart.md`. Phase 7's super-admin UI is the only consumer of `super_admin` privileges; Phase 6 itself ships zero `super_admin`-only surfaces, so the absence of any `super_admin` user during the Phase-6-only window is operationally invisible.

**Alternatives considered (full table from spec.md Q1)**:
- (A) Backfill assigns `super_admin` to the oldest `profiles.is_admin=true` user by `profiles.created_at`. REJECTED: implicit predicate; if the oldest admin is no longer the right person, manual cleanup is required; the predicate becomes a hidden product decision.
- (B) Backfill assigns `super_admin` to a hand-picked user_id baked into the migration. REJECTED: leaks a personal UUID into a checked-in file; the chosen identity is tied to the migration author at migration time.

---

## R-17 — PermissionChecker cache refresh observation points (Q2 — Session 2026-05-15 clarification)

**Decision**: **Option A** — exactly the three observation points in FR-015:
1. The auth-state listener (Phase 1's `SupabaseClientWrapper.authStateChanges()` consumed by Phase 5's `AuthBloc`) — calls `PermissionChecker.load()` on sign-in / token-refresh; `clear()` on sign-out.
2. The app's `WidgetsBindingObserver.didChangeAppLifecycleState(resumed)` — extends Phase 5's R-21 lifecycle observer to also call `PermissionChecker.refresh()` on resume.
3. The `_onAppResumedRefresh` handler on `AuthBloc` (the Phase 5 R-21 path that handles the `AppResumedRefresh` event for foreground-resume mid-session refresh) — extended in Phase 6 to also `await _permissionChecker.refresh()` after its existing `ProfileRefreshed` dispatch. No separate `refreshSession()` method exists on the bloc; the event-handled pattern is the canonical entry point.

No periodic timer. No Supabase Realtime subscription on `user_roles` in Phase 6.

**Rationale**: Mirrors Phase 5's R-21 pattern precisely; minimal overhead; no Realtime dependency. Role changes are rare in v1; the lifecycle-resume observation catches the change within seconds in practice. **Phase 22 follow-up**: when Phase 22 ships push + Realtime, the spec for that phase MUST revisit this and consider adding a Realtime subscription on `user_roles` keyed by `auth.uid()`. Project memory `project_phase22_perm_cache_revisit.md` carries this forward.

**Alternatives considered**:
- (B) Add a 60-second periodic timer. REJECTED: extra round-trips with no clear UX benefit beyond what lifecycle-resume already provides.
- (C) Add a Realtime subscription on `user_roles`. REJECTED: pulls Realtime in from Phase 22 ahead of schedule; expands scope.

---

## R-18 — PII cross-user read predicate retention (Q3 — Session 2026-05-15 clarification)

**Decision**: **Option A** — the Phase 5 `app_vault_secret_for_user(user_id, field_name)` helper continues to check `current_user_is_admin()` (which Phase 6 re-bodies to "admin or super_admin role"). Phase 6 does NOT refactor this helper to gate by a specific permission key. No new `users.view_pii` key is carved out in Phase 6. No cross-user PII write path is introduced.

**Rationale**: Tightest sensible privacy boundary; matches §9.1's role mappings where moderator has `users.view` but no PII-specific privilege; aligns with ADR-0001's minimum-necessary-data principle. **Forward-extensibility**: super_admin can reshape PII access via Phase 7's super-admin UI by editing role-permission mappings or role assignments — if a future spec carves out a `users.view_pii` permission key (or similar) and refactors the helper to gate by it, super_admin can grant the new key to a custom role without further code changes. Phase 6 ships the tightest default; later phases can broaden via configuration.

**Alternatives considered**:
- (B) Carve out a new `users.view_pii` permission key in Phase 6's seed. REJECTED: adds a key Phase 6 doesn't need yet; future-extensibility is preserved via the role-permission mapping editability in Phase 7.
- (C) Refactor the helper to check `current_user_has_permission('users.view')`. REJECTED: broadens what `users.view` means; grants moderators cross-user PII decrypt; privacy-sensitive expansion.

---

## R-19 — `permission_keys.dart` class layout

**Decision**: `lib/core/security/permission_keys.dart` exposes an `abstract class PermissionKeys { PermissionKeys._(); ... }` with `static const String` fields, one per seeded permission. The naming convention is camelCase matching the dot-namespaced key (`users.approve` → `usersApprove`). The file is organized into category sections via dartdoc `///` comments. Example:

```dart
abstract class PermissionKeys {
  PermissionKeys._();

  /// Users category — managing user accounts.
  static const String usersView = 'users.view';
  static const String usersApprove = 'users.approve';
  static const String usersReject = 'users.reject';
  static const String usersSuspend = 'users.suspend';

  /// Listings category — moderating listings.
  static const String listingsViewAll = 'listings.view_all';
  // ... etc., one per §9.1 key.

  /// All admin-category permission keys (used by the main-navigation admin-tile visibility check).
  static const Set<String> adminCategoryKeys = {
    usersView, usersApprove, usersReject, usersSuspend,
    listingsViewAll, listingsApprove, listingsReject, listingsEditAny, listingsDeleteAny,
    rolesView, permissionsManage,
    locationsManage, currenciesManage, adsManage, reportsManage,
    agenciesView, agenciesApprove, agenciesSuspend,
    settingsManage, auditLogsView, inquiriesViewAll,
  };
}
```

**Rationale**: An abstract class with a private constructor prevents instantiation; static const fields are compile-time constants. The `adminCategoryKeys` set is a derived constant that the navigation visibility check consumes via `PermissionChecker.any(PermissionKeys.adminCategoryKeys)`. Adding a future permission key in a later spec means adding one field plus (if it's an admin-category key) extending the `adminCategoryKeys` set — both compile-time-checked.

**Alternatives considered**:
- A `mixin` or `enum`. REJECTED: enum values can't be `'users.approve'` (they're identifiers); mixins are for behavior, not constants.
- One file per category. REJECTED: 24 keys fit comfortably in one file; splitting fragments the source of truth.
- Generated from the seeded `permissions` table. REJECTED for v1 (R-07); revisit when scale demands.

---

## R-20 — `user_roles` audit-trigger action key convention

**Decision**: Two action keys in v1 — `user_role.granted` (emitted by `trg_user_roles_audit_granted` AFTER INSERT) and `user_role.revoked` (emitted by `trg_user_roles_audit_revoked` AFTER DELETE). Phase 4's `log_audit` function receives the full key verbatim as `TG_ARGV[0]` and writes it to `audit_logs.action` unchanged. The backfill migration emits only `user_role.granted` rows (Phase 6 never DELETEs from `user_roles`); the `actor_user_id` column is NULL for these because the migration runs as `postgres` with no `auth.uid()`. Phase 7's super-admin UI will later emit both `granted` and `revoked` with `actor_user_id = <super_admin uuid>`. **Note: the audit-log column is `actor_user_id`, NOT `actor`.**

**Rationale**: Two specific action keys make audit-log grep practical (filter by mutation type with a single `WHERE action = …` clause). Matches Phase 5's pattern of one specific action key per trigger (Phase 5 uses `'profile.status_changed'` and `'account_approval.status_changed'`). Phase 4 `log_audit()` reusability invariant preserved — Phase 6 passes different `TG_ARGV[0]` values per trigger but does not edit the function. The two `user_role.*` action keys are listed in `supabase/docs/audit_logs.md`'s appended note (per the Phase 6 doc-update list).

**Alternatives considered**:
- A single action key `user_role.changed` for both INSERT and DELETE. REJECTED: less informative; an admin grep'ing for "who was promoted to admin recently" vs "who was revoked" becomes a two-step query (filter by action then join the before/after JSON to derive the verb). Two keys is the cheapest information-rich shape.
- Action keys named by the `roles.key` they reference (`role_admin_granted`, `role_admin_revoked`, etc.). REJECTED: explodes the action-key namespace; the `before_state` / `after_state` JSON already carries which `role_id` was granted/revoked.
- A single trigger passing `'user_role'` as the action and assuming `log_audit` appends `.inserted`/`.deleted`/`.updated`. **REJECTED — that assumption is false.** `log_audit` reads `TG_ARGV[0]` verbatim (see `supabase/migrations/20260506120004_create_audit_logs.sql:24`). Phase 6 analysis F1 caught this; this entry reflects the corrected design.

---

## R-21 — Lint guard for forbidden hardcoded role checks: NOT SHIPPED in Phase 6

**Decision**: Phase 6 does **NOT** ship a lint extension for forbidden hardcoded role checks. Phase 3's existing localization lint guard is untouched. FR-019 is enforced by PR review against Constitution VII. The Phase 6 grep verification task (T061) confirms the absence of forbidden patterns on the touched files at PR-review time.

**Rationale**: Phase 6's surface for FR-019 is small — the only new feature code in Phase 6 is `admin_home_page.dart` (which uses `PermissionChecker.has(...)` from the outset) and the small extension of `profile_page.dart`. There are no Phase 5 hardcoded-role-check sites to retrofit because Phase 5 itself used `profile.isAdmin` (a single field, not a string comparison) — the Phase 6 column-drop already eliminates that pattern. Adding a new lint guard for a non-existing risk is over-engineering. If a future spec re-introduces the risk (e.g., a feature that reads `user_roles.role.key` directly in feature code), that spec MAY revisit and add a lint rule then.

**Alternatives considered**:
- Make the lint extension a hard requirement in Phase 6 regardless of cost. REJECTED: time-box and value don't justify it; PR review + T061 grep is sufficient.
- Skip mention of lint extensions entirely. REJECTED: documenting the absence is itself a Constitution XII rule (no hidden product decisions about the absence of automation).

---

## R-22 — Profile entity `isAdmin` field removal (Phase 5 → Phase 6 migration impact on existing Dart code)

**Decision**: Phase 6 REMOVES the `isAdmin: bool` field from `lib/shared/domain/entities/profile.dart` in the same PR that drops the `profiles.is_admin` column. The Phase 5 `Profile` entity's `copyWith` and `props` are updated to drop the field. The data-layer mapper in `lib/features/profile/data/datasources/supabase_profile_datasource.dart` removes `is_admin` from the SELECT list. Every Phase 5 call site that referenced `profile.isAdmin` is rewritten:
- The home page admin tile visibility (Phase 5's `lib/features/home/presentation/pages/home_page.dart`) was the only Flutter call site of `profile.isAdmin`. It is rewritten to `context.read<PermissionChecker>().any(PermissionKeys.adminCategoryKeys)` (synchronous).
- The Phase 5 go_router redirect helper that gated `/admin` access via `profile.isAdmin` (in `lib/core/routing/auth_redirect.dart`) is rewritten the same way.
- The Phase 5 `AuthBloc` does NOT reference `profile.isAdmin` (verified at plan time via grep).

**Rationale**: Constitution IX preserved — the domain entity stays Supabase-free; the only thing changing is that one field is removed. Constitution VII enforced — no Dart code reads a hardcoded role-equivalent boolean from the Profile entity. The find-and-replace is straightforward because Phase 5's surface is small (two call sites total).

**Alternatives considered**:
- Keep `isAdmin: bool` on the entity, populated from the `PermissionChecker` cache at fetch time. REJECTED: introduces a derived field on a fetched entity that depends on session-scoped state — confusing semantically; the entity shouldn't carry session permissions.
- Keep `isAdmin: bool` on the entity, defaulting to false post-Phase-6 since the column is gone. REJECTED: misleading dead field; would silently change UI behavior for any future call site that re-introduces a `profile.isAdmin` reference.

---

## Inherited decisions (Phases 4 and 5)

These remain binding in Phase 6 without restatement:

- **R-02 (Phase 5)**: Apply migrations via Supabase MCP `apply_migration` against the remote project (no local Supabase).
- **R-05 (Phase 4)**: The reusable `log_audit()` trigger function is invoked unchanged for the new `user_roles` audit trigger.
- **R-12 (Phase 5)**: `current_user_is_admin()` body-swap pattern (single `CREATE OR REPLACE FUNCTION`; no policy file edited). Phase 6 swaps the body a second time using the same mechanism.
- **R-21 (Phase 5)**: The `WidgetsBindingObserver.didChangeAppLifecycleState(resumed)` pattern for mid-session state refresh — Phase 6 extends the existing Phase 5 observer to also call `PermissionChecker.refresh()`.
- **No new tests** (`feedback_no_new_tests.md`): no automated tests of any kind in Phase 6. Verification is manual SQL inspection + manual UI walk on the reference Infinix Note 8.
- **Dart-defines from `.env.json`** (project memory): every `flutter run`/`build` for Phase 6 verification MUST include `--dart-define-from-file=.env.json`.
- **Supabase Vault for PII** (ADR-0001): preserved. Phase 6 does not change Phase 5's Vault PII helpers; the read gate stays at `current_user_is_admin()` (R-18).
- **Git workflow** (`feedback_git_workflow.md`): ONE PR per spec (not per phase). The branch `006-roles-permissions` ships as a single squash-merged PR.
- **DEFERRED.md follow-up trigger** (`project_deferred_work.md`): before the Phase 6 squash-merge, review `specs/006-roles-permissions/DEFERRED.md` if any deferrals were recorded during implement.

---

**Summary**: 22 locked decisions. Three (R-16, R-17, R-18) resolve the Session 2026-05-15 spec-level clarifications. The rest (R-01 through R-15, R-19 through R-22) record technical choices made at planning time that the implement phase should not revisit without writing a new R-NN entry here.
