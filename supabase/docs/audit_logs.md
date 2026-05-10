# audit_logs

## Purpose

`audit_logs` is the append-only audit table for sensitive backend mutations. It
stores actor, action key, target identity, and before/after state snapshots for
audited changes.

## Columns

Defined in `supabase/migrations/20260506120004_create_audit_logs.sql`:

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `UUID` | NO | `gen_random_uuid()` | PK |
| `actor_user_id` | `UUID` | YES | `NULL` | FK to `auth.users(id)`, `ON DELETE SET NULL` |
| `action` | `TEXT` | NO | — | Action key, e.g. `profile.status_changed` |
| `target_type` | `TEXT` | NO | — | Target table/type |
| `target_id` | `TEXT` | YES | `NULL` | PK value resolved by trigger args |
| `before_state` | `JSONB` | YES | `NULL` | Pre-change snapshot |
| `after_state` | `JSONB` | YES | `NULL` | Post-change snapshot |
| `ip` | `INET` | YES | `NULL` | Trigger-context writes keep NULL in Phase 4 |
| `user_agent` | `TEXT` | YES | `NULL` | Trigger-context writes keep NULL in Phase 4 |
| `created_at` | `TIMESTAMPTZ` | NO | `now()` | Insert timestamp |

## `log_audit()` Trigger Function Contract

`log_audit()` is reusable and table-agnostic. Trigger configuration is passed via
`TG_ARGV`:

- `TG_ARGV[0]`: action key
- `TG_ARGV[1]`: captured column list (`*` for all)
- `TG_ARGV[2]`: PK column name (defaults to `id`)

The function resolves `target_id` using `TG_ARGV[2]` and filters update noise via
an `IS DISTINCT FROM` check over configured columns.

Contract reference:
`../../specs/004-supabase-foundation/contracts/log-audit-trigger-fn.md`.

## RLS Posture

RLS is enabled and Phase 4 applies one policy:

- `audit_logs_select_admin` (`TO authenticated`, gated by
  `current_user_is_admin()`)

No INSERT/UPDATE/DELETE client policies are defined. Writes occur through
`SECURITY DEFINER` server-side paths (trigger function).

## Later-Phase Reuse

Later phases attach the same `log_audit()` function to additional tables by adding
new triggers and appropriate `TG_ARGV` values (action key, column list, PK column):

- Phase 5: `account_approval_requests` ✅ **Shipped** in
  `20260510120005_attach_audit_trigger_account_approval_requests.sql` with
  `TG_ARGV = ('account_approval.status_changed',
  'status,rejection_reason,reviewed_by,reviewed_at', 'user_id')`. This is the
  first concrete reuse of `log_audit()` and validates the Phase 4 reusability
  invariant. Approve/reject through the
  `approve_account_approval_request` / `reject_account_approval_request` RPCs
  produces one `audit_logs` row with the admin as `actor_user_id` and the
  affected user's UUID as `target_id`.
- Phase 6: roles/permissions tables
- Phase 12: listings workflow
- Phase 18: reports/moderation
- Phase 19: agency flows
- Phase 21: ads

In Phase 4 trigger-context writes, `ip` and `user_agent` remain NULL. Later edge
function paths can populate those fields where request metadata is available.
