# Contract: Phase 7 Write-Side RLS Policies

**Owner**: Phase 7 (`supabase/migrations/20260516120002_create_phase7_write_policies.sql` + parallel files under `supabase/policies/`).
**Consumers**: every direct-SQL writer (including the `mutate_role`, `assign_role_to_user`, `revoke_role_from_user` RPCs — these run `SECURITY DEFINER` and bypass RLS in their function bodies, but their re-checks via `current_user_has_permission(...)` enforce the same gate).
**Stability**: Policy names (`<table>_phase7_<op>`) and gating predicates (`current_user_has_permission('<key>')`) are stable for v1.

---

## Purpose

Completes the write-side RLS coverage for the four Phase 6 catalog tables. Phase 6 left them with READ policies only (FR-009); Phase 7 adds INSERT/UPDATE/DELETE policies gated by the appropriate `permissions.key` via `current_user_has_permission(...)`. The Phase 6 read policies are preserved unchanged.

## Policy SQL (per-table)

### `supabase/policies/roles_phase7_write.sql`

```sql
DROP POLICY IF EXISTS roles_phase7_insert ON public.roles;
CREATE POLICY roles_phase7_insert ON public.roles
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_permission('roles.create'));

DROP POLICY IF EXISTS roles_phase7_update ON public.roles;
CREATE POLICY roles_phase7_update ON public.roles
  FOR UPDATE TO authenticated
  USING (public.current_user_has_permission('roles.update'))
  WITH CHECK (public.current_user_has_permission('roles.update'));

DROP POLICY IF EXISTS roles_phase7_delete ON public.roles;
CREATE POLICY roles_phase7_delete ON public.roles
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('roles.delete'));
```

**Defense-in-depth**: The Phase 6 `enforce_role_system_immutability` trigger fires BEFORE UPDATE OR DELETE; if a holder of `roles.delete` attempts to DELETE a `is_system=true` row, the trigger raises `42501` before the row is touched.

### `supabase/policies/role_permissions_phase7_write.sql`

```sql
DROP POLICY IF EXISTS role_permissions_phase7_insert ON public.role_permissions;
CREATE POLICY role_permissions_phase7_insert ON public.role_permissions
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_permission('permissions.manage'));

DROP POLICY IF EXISTS role_permissions_phase7_delete ON public.role_permissions;
CREATE POLICY role_permissions_phase7_delete ON public.role_permissions
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('permissions.manage'));
```

**Notes**:
- No UPDATE policy — `role_permissions` rows are immutable post-insert (Phase 6 R-15).
- The cascade from `roles ON DELETE CASCADE → role_permissions` fires when a role is deleted via the `roles_phase7_delete` policy; the cascade's DELETE on `role_permissions` runs as the same authenticated role, and the `role_permissions_phase7_delete` policy admits it (the user already had `permissions.manage` to compose the role-delete in `mutate_role` anyway).

### `supabase/policies/user_roles_phase7_write.sql`

```sql
DROP POLICY IF EXISTS user_roles_phase7_insert ON public.user_roles;
CREATE POLICY user_roles_phase7_insert ON public.user_roles
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_permission('permissions.manage'));

DROP POLICY IF EXISTS user_roles_phase7_delete ON public.user_roles;
CREATE POLICY user_roles_phase7_delete ON public.user_roles
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('permissions.manage'));
```

**Notes**:
- No UPDATE policy — Phase 6 R-15 invariant preserved.
- The Phase 6 self-read + admin-cross-read policies are preserved (the Phase 7 migration does NOT touch them).
- The `assign_role_to_user` and `revoke_role_from_user` RPCs run `SECURITY DEFINER` and bypass these policies during their writes; the same `current_user_has_permission('permissions.manage')` check happens inside each RPC body (explicit `IF NOT ... THEN RAISE`). The RLS policies cover the direct-SQL path (a holder of `permissions.manage` writing via Supabase MCP `execute_sql` simulating their JWT).
- The two-step super_admin grant confirmation (R-04) and the unconditional self-revoke block (R-05) are enforced inside the RPCs only — the RLS policies do NOT carry those checks. Rationale: a direct-SQL writer authenticated as a super_admin holds `permissions.manage` and can therefore directly INSERT a `super_admin` role assignment for themselves bypassing the RPC. This is acceptable for v1 because direct-SQL access is privileged (only `postgres` and the super_admin themselves can do it from Supabase MCP `execute_sql`); the in-app surface is what the typed-confirmation gate protects.

## `permissions` table: no Phase 7 write policy

The v1 catalog is closed (Phase 6 assumption preserved by Phase 7 R-03). Phase 7 does NOT add write policies on `permissions` — there is no in-app or operational path that mutates the catalog. A future spec that adds a new permission key authors its own write policy alongside the migration that INSERTs the row.

## Phase 4/5/6 policy files NOT edited

The Phase 7 migration does NOT touch:

- `supabase/policies/profiles_policies.sql` (Phase 4)
- `supabase/policies/user_preferences_policies.sql` (Phase 4)
- `supabase/policies/audit_logs_policies.sql` (Phase 4)
- `supabase/policies/account_approval_requests_policies.sql` (Phase 5)
- `supabase/policies/roles_policies.sql` (Phase 6 read policy)
- `supabase/policies/permissions_policies.sql` (Phase 6 read policy)
- `supabase/policies/role_permissions_policies.sql` (Phase 6 read policy)
- `supabase/policies/user_roles_policies.sql` (Phase 6 read policies)
- `supabase/policies/profiles_phase6_users_view.sql` (Phase 6 cross-user read on profiles)

The Phase 4 R-05 / Phase 5 / Phase 6 central-helper invariant is preserved a third time. (Phase 7 adds new policy files under new names; no existing file is opened in a Phase 7 PR.)

## Verification (Supabase MCP `execute_sql`)

```sql
-- 1. All Phase 7 write policies exist
SELECT schemaname, tablename, policyname, cmd FROM pg_policies
WHERE tablename IN ('roles', 'role_permissions', 'user_roles')
  AND policyname LIKE '%_phase7_%'
ORDER BY tablename, policyname;
-- Expected:
--   roles                roles_phase7_delete            DELETE
--   roles                roles_phase7_insert            INSERT
--   roles                roles_phase7_update            UPDATE
--   role_permissions     role_permissions_phase7_delete DELETE
--   role_permissions     role_permissions_phase7_insert INSERT
--   user_roles           user_roles_phase7_delete       DELETE
--   user_roles           user_roles_phase7_insert       INSERT

-- 2. Phase 6 read policies still exist (sanity)
SELECT schemaname, tablename, policyname FROM pg_policies
WHERE tablename IN ('roles', 'role_permissions', 'user_roles')
  AND policyname NOT LIKE '%_phase7_%'
ORDER BY tablename, policyname;
-- Expected: the Phase 6 read policies — at minimum one per table.

-- 3. Simulate a non-super-admin authenticated session
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<regular-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;

INSERT INTO public.roles (key, display_name, is_system, description) VALUES ('test_blocked', '{"ar":"اختبار","en":"Test"}', false, 'should fail');
-- Expected: ERROR 42501 (insufficient_privilege) — RLS rejects the insert because the user does not hold roles.create.

RESET ROLE;

-- 4. Simulate a super_admin session (after bootstrap)
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<super_admin-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;

INSERT INTO public.roles (key, display_name, is_system, description) VALUES ('test_allowed', '{"ar":"اختبار","en":"Test"}', false, 'should succeed')
RETURNING id;
-- Expected: 1 row affected — super_admin holds roles.create via the full-catalog mapping.

DELETE FROM public.roles WHERE key = 'test_allowed';
-- Expected: 1 row affected — super_admin holds roles.delete.

RESET ROLE;
```

## Invariants

- **All policies are `WITH CHECK` and/or `USING` predicates that call `current_user_has_permission(<key>)`** — the centralized helper, not a hardcoded role check.
- **No policy joins to `auth.uid()` directly** — the `current_user_has_permission(...)` helper does the join internally.
- **Defense-in-depth at the RPC layer**: the three Phase 7 RPCs (`mutate_role`, `assign_role_to_user`, `revoke_role_from_user`) re-check the same permission keys inside their function bodies. A user who holds `permissions.manage` can write directly via SQL (admitted by RLS); the RPC re-checks for the in-app path so the audit trail and structured error responses are consistent.

## Forward references

- Phase 19 (Agencies) MAY add new write-side policies on `roles` / `role_permissions` (e.g., for agency_admin-specific permission management). If so, they author their own policy files; this file is unchanged.
- Phase 22 (Push + Realtime) may introduce policies on `user_roles` for Realtime subscription scope; if so, they live in a new file.
