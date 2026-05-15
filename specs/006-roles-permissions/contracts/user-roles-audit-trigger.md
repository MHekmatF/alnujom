# Contract: `user_roles` Audit Trigger

**Owner**: Phase 6 (`supabase/migrations/20260515120004_create_user_roles.sql`).
**Consumers**: implicit — fires on every INSERT, UPDATE, DELETE against `user_roles`. The `audit_logs` rows it emits are consumed by Phase 7's super-admin UI (action filters), by any future audit-log viewer, and by `audit_logs.view`-gated admin reads.
**Stability**: Trigger names (`trg_user_roles_audit_granted`, `trg_user_roles_audit_revoked`) and action keys (`user_role.granted`, `user_role.revoked`) are stable for v1. If a future spec adds a third trigger for UPDATEs, it will use a parallel name and a distinct action key (e.g., `user_role.changed`).

---

## Purpose

Captures every mutation of the `user_roles` table as an `audit_logs` row, reusing Phase 4's `log_audit()` function unchanged (Phase 4 R-05 reusability invariant preserved).

## Triggers (two, per Phase 5 convention)

Phase 4's `log_audit()` reads the action string **verbatim** from `TG_ARGV[0]` — it does NOT append a TG_OP-derived verb (see `supabase/migrations/20260506120004_create_audit_logs.sql` line 24). So Phase 5's convention (followed here) is one trigger per legal mutation event, each with a distinct full action key passed as the first argument.

```sql
-- (a) AFTER INSERT — role assignment granted to a user.
DROP TRIGGER IF EXISTS trg_user_roles_audit_granted ON public.user_roles;
CREATE TRIGGER trg_user_roles_audit_granted
  AFTER INSERT ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('user_role.granted', '*', 'user_id');

-- (b) AFTER DELETE — role assignment revoked from a user.
DROP TRIGGER IF EXISTS trg_user_roles_audit_revoked ON public.user_roles;
CREATE TRIGGER trg_user_roles_audit_revoked
  AFTER DELETE ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('user_role.revoked', '*', 'user_id');
```

No UPDATE trigger in v1 — `user_roles` rows are immutable after insert (no Phase 6 or Phase 7 mutation path UPDATEs an existing row; assignment changes are INSERT + DELETE pairs). If a future spec ever updates an existing row, that spec adds `trg_user_roles_audit_changed AFTER UPDATE … EXECUTE FUNCTION log_audit('user_role.changed', '*', 'user_id')`.

## `log_audit()` parameters (from Phase 4)

- `TG_ARGV[0]` = the full action key (e.g., `'user_role.granted'`). Stored verbatim in `audit_logs.action`.
- `TG_ARGV[1]` = `'*'`: all columns captured into `before_state` / `after_state` JSON. (Could be a comma-separated list like `'user_id,role_id'` to filter, but for INSERT/DELETE on small tables `'*'` is simplest.)
- `TG_ARGV[2]` = `'user_id'`: the column whose value populates `audit_logs.target_id`. The target of a role mutation is the affected user.

## Action keys emitted

- `user_role.granted` (one per INSERT row — the Phase 6 backfill emits N_pre_admin + M_profiles of these; Phase 7's super-admin UI emits one per grant action).
- `user_role.revoked` (one per DELETE row — only Phase 7's super-admin UI emits these; Phase 6 never DELETEs from `user_roles`).

## Actor field (`audit_logs.actor_user_id`)

The `audit_logs` table's actor column is **`actor_user_id`** (UUID, FK to `auth.users(id)` ON DELETE SET NULL). `log_audit` sets it to `auth.uid()` at trigger fire time.

- **In-app mutations from Phase 7 onward**: `actor_user_id = auth.uid()` (the super_admin performing the grant/revoke).
- **The Phase 6 FR-011 backfill migration** (T037): `actor_user_id = NULL` (the migration runs as `postgres` with no JWT; `auth.uid()` returns NULL).
- **The Phase 6 FR-013 auto-`user`-role trigger** (T014, T015): `actor_user_id = NULL` for the FR-011 backfill phase (no `auth.uid()`); for live signups post-Phase-6, `auth.uid()` resolves to the new user (since `SECURITY DEFINER` does NOT swap `auth.uid()` — it only swaps the role for permission checks; the JWT context is preserved). So legitimate signups will produce audit rows with `actor_user_id = <new-user-uuid>` — the new user is "auditing themselves" being granted the default `user` role. That's an acceptable signal (the row is self-explanatory: someone signed up).

## Invariants

- **Every mutation produces exactly one audit-log row**. AFTER-ROW means per-row; bulk operations produce one row per affected user_roles row.
- **`before_state` / `after_state` JSON contains the full row**: enables before/after diff inspection in Phase 7's audit-log viewer.
- **`log_audit` itself is unchanged**: Phase 6 does NOT edit Phase 4's `log_audit` function. The R-05 reusability invariant holds a second time (Phase 5 also reused unchanged for its `account_approval_requests` trigger).

## Verification (Supabase MCP `execute_sql`)

After the FR-011 backfill migration runs:

```sql
-- 1. The backfill produces 'user_role.granted' rows. Two INSERT loops:
--    (a) admin role for prior is_admin=true users; (b) user role for every existing profile.
SELECT action, count(*) AS n FROM public.audit_logs
WHERE action LIKE 'user_role.%' AND actor_user_id IS NULL
GROUP BY action;
-- Expected: 'user_role.granted' with n ≈ N_pre_admin + M_profiles. No 'user_role.revoked' rows (Phase 6 does not delete).

-- 2. before_state is 'null'::jsonb for INSERTs; after_state holds the new row.
SELECT before_state, after_state FROM public.audit_logs
WHERE action = 'user_role.granted' LIMIT 1;
-- Expected: before_state = 'null'::jsonb; after_state is a JSON object with id, user_id, role_id, granted_by, granted_at, created_at.

-- 3. target_id matches the user_id column from the inserted row.
SELECT target_id, after_state->>'user_id' AS user_id_from_after
FROM public.audit_logs WHERE action = 'user_role.granted' LIMIT 5;
-- Expected: target_id = user_id_from_after for every row.

-- 4. Optional — the audit row's target_type is the table name.
SELECT DISTINCT target_type FROM public.audit_logs WHERE action = 'user_role.granted';
-- Expected: 'user_roles' (a single value — TG_TABLE_NAME is the un-schema-qualified table name).
```

## Forward references

- Phase 7's super-admin UI brings the audit-log viewer. The `user_role.*` action keys land in that view alongside Phase 5's `account_approval.*` actions.
- The audit-log retention policy (how long these rows live) is a Phase 24 release-polish question; v1 retains forever.
