# Contract: Phase 7 Audit Triggers (on `roles`, `role_permissions`, `permissions`)

**Owner**: Phase 7 (`supabase/migrations/20260516120001_create_phase7_audit_triggers.sql`).
**Consumers**: implicit — fires on every mutation of the three tables. Audit rows are consumed by future audit-log viewers (Phase 24 candidate), by `audit_logs.view`-gated admin reads.
**Stability**: Trigger names (`trg_roles_audit_*`, `trg_role_permissions_audit_*`, `trg_permissions_audit_*`) and action keys (`role.*`, `role_permission.*`, `permission.*`) are stable for v1.

---

## Purpose

Extends the Phase 6 audit coverage (which covered `user_roles` only) to the other three Phase 6 catalog tables, completing the §9.4 audit-trigger mandate for the role/permission graph. Reuses Phase 4's `log_audit()` function unchanged (Phase 4 R-05 reusability invariant preserved a third time).

## Triggers

```sql
-- 1. roles
DROP TRIGGER IF EXISTS trg_roles_audit_created ON public.roles;
CREATE TRIGGER trg_roles_audit_created
  AFTER INSERT ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role.created', '*', 'id');

DROP TRIGGER IF EXISTS trg_roles_audit_updated ON public.roles;
CREATE TRIGGER trg_roles_audit_updated
  AFTER UPDATE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role.updated', '*', 'id');

DROP TRIGGER IF EXISTS trg_roles_audit_deleted ON public.roles;
CREATE TRIGGER trg_roles_audit_deleted
  AFTER DELETE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role.deleted', '*', 'id');

-- 2. role_permissions (INSERT/DELETE only — rows are immutable post-insert)
DROP TRIGGER IF EXISTS trg_role_permissions_audit_granted ON public.role_permissions;
CREATE TRIGGER trg_role_permissions_audit_granted
  AFTER INSERT ON public.role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role_permission.granted', '*', 'role_id');

DROP TRIGGER IF EXISTS trg_role_permissions_audit_revoked ON public.role_permissions;
CREATE TRIGGER trg_role_permissions_audit_revoked
  AFTER DELETE ON public.role_permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('role_permission.revoked', '*', 'role_id');

-- 3. permissions (defensive — v1 catalog is closed)
DROP TRIGGER IF EXISTS trg_permissions_audit_created ON public.permissions;
CREATE TRIGGER trg_permissions_audit_created
  AFTER INSERT ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('permission.created', '*', 'id');

DROP TRIGGER IF EXISTS trg_permissions_audit_updated ON public.permissions;
CREATE TRIGGER trg_permissions_audit_updated
  AFTER UPDATE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('permission.updated', '*', 'id');

DROP TRIGGER IF EXISTS trg_permissions_audit_deleted ON public.permissions;
CREATE TRIGGER trg_permissions_audit_deleted
  AFTER DELETE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('permission.deleted', '*', 'id');
```

## `log_audit()` parameters (Phase 4 contract preserved)

- `TG_ARGV[0]` = full action key (e.g., `'role.created'`). Stored verbatim in `audit_logs.action`.
- `TG_ARGV[1]` = `'*'`: all columns captured into `before_state` (for UPDATE/DELETE) / `after_state` (for INSERT/UPDATE) JSON.
- `TG_ARGV[2]` = the column whose value populates `audit_logs.target_id`:
  - `roles`, `permissions`: `'id'` (the row's own id).
  - `role_permissions`: `'role_id'` (the operationally-meaningful target — the role that gained/lost a permission).

## Action keys emitted

- `role.created` — one per `roles` INSERT.
- `role.updated` — one per `roles` UPDATE.
- `role.deleted` — one per `roles` DELETE (system-role rows fire `enforce_role_system_immutability` BEFORE this can run; only non-system rows produce this row).
- `role_permission.granted` — one per `role_permissions` INSERT (the cascade from `roles ON DELETE CASCADE → role_permissions` does NOT emit these; cascades emit DELETEs).
- `role_permission.revoked` — one per `role_permissions` DELETE (including cascade deletes when a role is deleted).
- `permission.created` / `permission.updated` / `permission.deleted` — defensive; the v1 super-admin UI does NOT mutate `permissions` rows.

## Actor field (`audit_logs.actor_user_id`)

- **In-app mutations from Phase 7's `mutate_role` RPC**: `actor_user_id = auth.uid()` (the super_admin performing the mutation). The RPC is `SECURITY DEFINER` but preserves the JWT context for `auth.uid()`.
- **Direct-SQL mutations via Supabase MCP `execute_sql` running as `postgres`**: `actor_user_id = NULL` (no JWT). Distinguishes operational/migration writes from in-app writes.
- **Cascade fires from `roles → role_permissions`**: `actor_user_id` is the value at the time of the parent DELETE — typically `auth.uid()` of the calling super_admin.

## Phase 6 triggers NOT touched

The following Phase 6 triggers continue to fire unchanged; the Phase 7 migration does NOT redefine or drop them:

- `trg_user_roles_audit_granted` (AFTER INSERT on `user_roles`)
- `trg_user_roles_audit_revoked` (AFTER DELETE on `user_roles`)
- `trg_profiles_auto_user_role` (AFTER INSERT on `profiles`)
- `trg_roles_enforce_system_immutability` (BEFORE UPDATE OR DELETE on `roles`)

## Invariants

- **Idempotency**: every `CREATE TRIGGER` is preceded by `DROP TRIGGER IF EXISTS` for safe re-application.
- **Per-row granularity (R-12)**: each affected row produces one audit row.
- **`log_audit()` unchanged**: Phase 4 R-05 reusability invariant preserved.
- **No interference**: re-applying the migration verifies that `SELECT tgname, count(*) FROM pg_trigger GROUP BY tgname HAVING count(*) > 1` returns zero rows (SC-018 / SC-014).

## Verification (Supabase MCP `execute_sql`)

```sql
-- 1. All 8 triggers exist
SELECT tgname FROM pg_trigger
WHERE tgrelid IN ('public.roles'::regclass, 'public.role_permissions'::regclass, 'public.permissions'::regclass)
  AND NOT tgisinternal
ORDER BY tgname;
-- Expected: 8 rows — the 3 roles triggers, 2 role_permissions triggers, 3 permissions triggers, PLUS Phase 6's enforce_role_system_immutability and set_updated_at on roles.
-- (set_updated_at and enforce_role_system_immutability are NOT new in Phase 7 — they appear here because pg_trigger lists all triggers on the relation.)

-- 2. Run a synthetic mutation against `roles` via privileged SQL
INSERT INTO public.roles (key, display_name, is_system, description)
VALUES ('test_role', '{"ar":"اختبار","en":"Test"}', false, 'temp')
RETURNING id, updated_at;

-- 3. Verify the audit row
SELECT action, actor_user_id, target_id, target_type, before_state, after_state
FROM public.audit_logs
WHERE action = 'role.created'
ORDER BY created_at DESC LIMIT 1;
-- Expected: action='role.created', actor_user_id IS NULL (postgres session), target_id = <new role id>, target_type='roles',
--   before_state = 'null'::jsonb, after_state = {"id":..., "key":"test_role", ...}.

-- 4. Update the row
UPDATE public.roles SET description = 'temp updated' WHERE key = 'test_role' RETURNING updated_at;

-- 5. Verify the role.updated audit row
SELECT action, before_state->>'description' AS before_desc, after_state->>'description' AS after_desc
FROM public.audit_logs
WHERE action = 'role.updated'
ORDER BY created_at DESC LIMIT 1;
-- Expected: before_desc='temp', after_desc='temp updated'.

-- 6. Insert into role_permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r, public.permissions p
WHERE r.key = 'test_role' AND p.key = 'users.view';

-- 7. Verify the role_permission.granted audit row
SELECT action, target_id, after_state->>'role_id' AS role_id_in_after, after_state->>'permission_id' AS permission_id_in_after
FROM public.audit_logs
WHERE action = 'role_permission.granted'
ORDER BY created_at DESC LIMIT 1;
-- Expected: target_id matches the test_role id; role_id_in_after = target_id; permission_id_in_after = users.view's id.

-- 8. Delete the role (cascade fires on role_permissions)
DELETE FROM public.roles WHERE key = 'test_role';

-- 9. Verify the role.deleted + cascaded role_permission.revoked rows
SELECT action, count(*) FROM public.audit_logs
WHERE action IN ('role.deleted', 'role_permission.revoked')
  AND created_at > now() - interval '1 minute'
GROUP BY action;
-- Expected: role.deleted = 1, role_permission.revoked >= 1 (one per cascaded delete).

-- 10. Cleanup verification: the test_role is gone
SELECT count(*) FROM public.roles WHERE key = 'test_role';
-- Expected: 0
```

## Forward references

- Phase 24's audit-log viewer (deferred) will surface these action keys alongside Phase 5's `account_approval.*` and Phase 6's `user_role.*` keys.
- The retention policy for these rows is a Phase 24 question; v1 retains forever.
