# Contract: `account_approval_requests` Audit Trigger

**Owner**: Phase 5 (`supabase/migrations/20260510120005_attach_audit_trigger_account_approval_requests.sql`).
**Consumers**: anyone reading `audit_logs` to reconstruct admin actions on user accounts (Phase 7 super-admin UI; future moderation review tools).
**Stability**: Stable across the v1 lifecycle. The trigger uses Phase 4's `log_audit()` reusable function unchanged; the only Phase-5-owned values are the `TG_ARGV` strings, which are documented here as a stable contract.

---

## Purpose

Whenever an admin action transitions an `account_approval_requests` row's status (or the related fields), exactly one row appears in `audit_logs` capturing the actor (the admin), the action key, the target user, and the before/after state of the changed columns. This contract is the first concrete reuse of Phase 4's `log_audit()` function and validates the Phase 4 reusability invariant.

## Trigger declaration

```sql
DROP TRIGGER IF EXISTS trg_account_approval_requests_audit_status ON account_approval_requests;
CREATE TRIGGER trg_account_approval_requests_audit_status
  AFTER UPDATE OF status, rejection_reason, reviewed_by, reviewed_at
  ON account_approval_requests
  FOR EACH ROW
  WHEN (
    OLD.status IS DISTINCT FROM NEW.status
    OR OLD.rejection_reason IS DISTINCT FROM NEW.rejection_reason
    OR OLD.reviewed_by IS DISTINCT FROM NEW.reviewed_by
    OR OLD.reviewed_at IS DISTINCT FROM NEW.reviewed_at
  )
  EXECUTE FUNCTION log_audit(
    'account_approval.status_changed',
    'status,rejection_reason,reviewed_by,reviewed_at',
    'user_id'
  );
```

## `TG_ARGV` contract (per Phase 4 R-04)

| Position | Value | Meaning |
|---|---|---|
| `TG_ARGV[0]` | `'account_approval.status_changed'` | The `audit_logs.action` text key |
| `TG_ARGV[1]` | `'status,rejection_reason,reviewed_by,reviewed_at'` | Comma-separated column list captured in `before_state`/`after_state` JSON |
| `TG_ARGV[2]` | `'user_id'` | The column on the row to use as `audit_logs.target_id` (the row's actual PK is its synthetic UUID `id`, but the meaningful audit target is `user_id`) |

## What gets written to `audit_logs`

Per Phase 4's `log_audit()` body, each fired event writes one row:

| Column | Source |
|---|---|
| `id` | `gen_random_uuid()` (Phase 4 `audit_logs` default) |
| `actor_user_id` | `auth.uid()` from the calling session (the admin) |
| `action` | `'account_approval.status_changed'` |
| `target_type` | `TG_TABLE_NAME` = `'account_approval_requests'` |
| `target_id` | `NEW.user_id::text` (per `TG_ARGV[2]`) |
| `before_state` | JSON `{ "status": "<old>", "rejection_reason": <old>, "reviewed_by": <old>, "reviewed_at": <old> }` |
| `after_state` | JSON `{ "status": "<new>", "rejection_reason": <new>, "reviewed_by": <new>, "reviewed_at": <new> }` |
| `ip` | NULL (Phase 4 leaves IP/user_agent capture to higher-level audits) |
| `user_agent` | NULL |
| `created_at` | `now()` |

## Invariants

- **Exactly one row per state transition**: the `WHEN` clause prevents no-op `UPDATE` statements (e.g., `UPDATE … SET updated_at = now() WHERE …` without changing the watched columns) from emitting spurious audit rows.
- **Fires AFTER the UPDATE**: the row is already in its new state when the trigger reads `NEW`; the trigger does not block or modify the parent UPDATE.
- **Reuses `log_audit()` unchanged**: Phase 4's function signature and body are not modified; this validates the Phase 4 reusability invariant.

## Verification

After applying `20260510120005_attach_audit_trigger_account_approval_requests.sql`:

```sql
-- 1. Confirm the trigger exists.
SELECT tgname, tgrelid::regclass
FROM pg_trigger
WHERE tgname = 'trg_account_approval_requests_audit_status';

-- 2. Approve a test pending request (via the RPC, which exercises the trigger end-to-end).
SELECT approve_account_approval_request('<test-user-uuid>'::uuid);

-- 3. Confirm exactly one audit_logs row appeared.
SELECT actor_user_id, action, target_type, target_id, before_state, after_state, created_at
FROM audit_logs
WHERE target_type = 'account_approval_requests' AND target_id = '<test-user-uuid>'
ORDER BY created_at DESC
LIMIT 1;
```

Expected: one row with `action = 'account_approval.status_changed'`, `before_state.status = 'pending'`, `after_state.status = 'approved'`, etc.
