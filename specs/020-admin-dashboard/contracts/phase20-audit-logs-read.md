# Contract: `audit_logs` admin read access (Phase 20)

**Type**: RLS SELECT policy predicate change on the existing `public.audit_logs` table (no column/table change).
**Created by**: P2 — `supabase/migrations/20260601120004_align_audit_logs_read_to_permission.sql`.
**Consumed by**: P2 — `lib/features/admin/audit_logs/data/datasources/` via `supabase.from('audit_logs').select(...)` (runtime RLS contract; not a Dart import).

## Background (verified against the repo)

The policy `audit_logs_select_admin` already exists from Phase 4 — `supabase/migrations/20260506120005_enable_rls_default.sql`:

```sql
-- EXISTING (Phase 4):
CREATE POLICY audit_logs_select_admin ON audit_logs
  FOR SELECT TO authenticated
  USING (current_user_is_admin());
```

`current_user_is_admin()` was redefined by Phase 6 (`supabase/migrations/20260515120006_swap_admin_predicate_to_role_check.sql`) to a **role-based** check:

```sql
SELECT EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id
               WHERE ur.user_id = auth.uid() AND r.key IN ('admin','super_admin'));
```

So the audit-log read gate is currently **role-based** (`admin`/`super_admin` role), NOT the data-driven `audit_logs.view` permission. The spec (FR-003 + FR-021) requires the Audit-logs tile AND viewer to be gated by `audit_logs.view`, and Principle VII forbids role-based gates in favor of data-driven permissions. The frontend tile (gated on `audit_logs.view`) and the backend RLS (gated on the role) would therefore use different gates — coinciding today (only `admin`/`super_admin` hold `audit_logs.view`) but diverging for any future custom role.

## Change (Phase 20)

Swap the predicate so backend and frontend use the same data-driven gate:

```sql
-- supabase/migrations/20260601120004_align_audit_logs_read_to_permission.sql
DROP POLICY IF EXISTS audit_logs_select_admin ON public.audit_logs;
CREATE POLICY audit_logs_select_admin ON public.audit_logs
  FOR SELECT TO authenticated
  USING (current_user_has_permission('audit_logs.view'));
```

- **Read**: only callers holding `audit_logs.view` (today ≡ admin/super_admin — no access change now; diverges only for future custom roles, which is the intended data-driven behavior).
- **Write**: NO client write policy exists or is added — the table stays append-only; `log_audit()` (SECURITY DEFINER, Phase 4) is the only writer. Phase 20 introduces no INSERT/UPDATE/DELETE path.
- **anon**: no policy → denied.

## Read shape (for the viewer)

Columns: `id, actor_user_id, action, target_type, target_id, before_state, after_state, created_at`.
Order: `created_at DESC` (uses existing `idx_audit_logs_created_at`).
Pagination: bounded page size (cursor on `(created_at, id)` or range) — no unbounded scan.

## Acceptance checks

1. **Predicate swapped** — after the migration, `pg_policies` shows `audit_logs_select_admin` with `current_user_has_permission('audit_logs.view')` in its `USING` clause (not `current_user_is_admin()`).
2. From a session holding `audit_logs.view`, `select … from audit_logs order by created_at desc limit N` returns rows (SC-012).
3. From a session WITHOUT `audit_logs.view`, the same select returns zero rows at the wire level (SC-012).
4. From `anon`, zero rows.
5. No INSERT/UPDATE/DELETE succeeds from any client session (table remains append-only).
