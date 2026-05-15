# account_approval_requests

## Purpose

`account_approval_requests` tracks the **first-review outcome** of admin
approval for every registered user. One row per user. Lifecycle in Phase 5:
`pending → approved | rejected` (terminal in v1).

This is **deliberately narrower** than `profiles.account_status`, which tracks
the broader account lifecycle (`pending → approved → suspended → ...`).
Suspending an already-approved user does NOT change this table; the request
row stays at `approved` while `profiles.account_status` flips. Phase 7's
super-admin UI will add transitions back to `pending` (reopen-rejection); when
it does, the `UNIQUE (user_id)` constraint relaxes to a partial unique index.

> **Filename note**: `IMPLEMENTATION_PLAN.md` Phase 5 originally hinted at
> `0007_create_account_approval_requests.sql`. The actual filename follows the
> 14-digit-timestamp convention locked in Phase 4 R-02:
> `20260510120001_create_account_approval_requests.sql`. See
> `../../specs/005-auth-profile/research.md` R-01 for the rationale.

## Columns

Defined in `supabase/migrations/20260510120001_create_account_approval_requests.sql`:

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `UUID` | NO | `gen_random_uuid()` | PK; synthetic so Phase 7 can add reopen-history rows without violating PK |
| `user_id` | `UUID` | NO | — | `UNIQUE`; FK to `auth.users(id)` `ON DELETE CASCADE` |
| `status` | `account_approval_status` | NO | `'pending'` | Enum `{pending, approved, rejected}` — narrower than `profiles.account_status` by design |
| `rejection_reason` | `TEXT` | YES | `NULL` | Required (`length>0`) when `status='rejected'`; must be NULL otherwise (CHECK) |
| `reviewed_by` | `UUID` | YES | `NULL` | FK to `auth.users(id)` `ON DELETE SET NULL`; populated when status moves out of pending |
| `reviewed_at` | `TIMESTAMPTZ` | YES | `NULL` | Populated when status moves out of pending |
| `created_at` | `TIMESTAMPTZ` | NO | `now()` | |
| `updated_at` | `TIMESTAMPTZ` | NO | `now()` | Maintained by `set_updated_at` trigger |

Two CHECK constraints enforce lifecycle invariants:
- `account_approval_requests_rejection_reason_when_rejected` — rejection always
  has a non-empty reason; pending/approved rows have `rejection_reason IS NULL`.
- `account_approval_requests_reviewed_when_decided` — pending rows have
  `reviewed_by IS NULL` AND `reviewed_at IS NULL`; decided rows have both
  populated.

A partial index speeds the admin queue's "newest pending first" query:

```sql
CREATE INDEX idx_account_approval_requests_status_pending
  ON account_approval_requests (created_at DESC)
  WHERE status = 'pending';
```

## Auto-Population

`auto_create_account_approval_request()` is a SECURITY DEFINER trigger function
attached to `AFTER INSERT ON profiles`. Whenever a new `profiles` row is
inserted (transitively whenever `auth.users` gets a new row, via Phase 4's
`handle_new_auth_user`), an `account_approval_requests` row is created with
`status = 'pending'` and the same `user_id`. Idempotent via
`ON CONFLICT (user_id) DO NOTHING`.

Contract reference:
`../../specs/005-auth-profile/contracts/account-approval-trigger.md`.

## RLS Posture

RLS enabled in the same migration with three policies:

| Policy | Operation | Roles | Predicate |
|---|---|---|---|
| `account_approval_requests_self_read` | SELECT | `authenticated` | `user_id = auth.uid()` |
| `account_approval_requests_admin_read` | SELECT | `authenticated` | `current_user_is_admin()` |
| `account_approval_requests_admin_update` | UPDATE | `authenticated` | `current_user_is_admin()` (USING + WITH CHECK) |

No INSERT policy: the trigger is the only writer. No DELETE policy: rows are
kept for audit; cascade-only via `auth.users(id) ON DELETE CASCADE`.

Anon role has no policy and is denied by RLS default.

## Admin RPCs

Two SECURITY DEFINER RPCs handle status transitions atomically with the
matching `profiles.account_status` write:

- `approve_account_approval_request(p_user_id UUID) RETURNS VOID`
- `reject_account_approval_request(p_user_id UUID, p_reason TEXT) RETURNS VOID`

Both check `current_user_is_admin()` first (raise `42501` if false), then UPDATE
the request row (raise `02000` if no pending row exists), then UPDATE
`profiles.account_status` (guarded by `account_status='pending'` so out-of-band
flips aren't silently overwritten). Both UPDATEs run in the same transaction —
a failure on either rolls back both.

`EXECUTE` granted to `authenticated`; revoked from `anon`
(`20260510120006_phase5_advisor_hardening.sql`).

Contract reference:
`../../specs/005-auth-profile/research.md` (R-14).

> **Phase 6 note**: The admin-read and admin-update policies (`account_approval_requests_admin_read`,
> `account_approval_requests_admin_update`) continue to gate on `current_user_is_admin()` whose
> body Phase 6 swapped from a column-read to a role-membership check
> (`20260515120006_swap_admin_predicate_to_role_check.sql`). The same set of users is admitted —
> prior Phase 5 admins, now holding the `admin` role in `user_roles`. Phase 5's admin queue
> behaviour is unchanged. No policy file for this table is edited by Phase 6.
>
> Contract reference: `../../specs/006-roles-permissions/contracts/admin-predicate-v6.md`.

## Audit Coverage

`trg_account_approval_requests_audit_status` fires
`AFTER UPDATE OF status, rejection_reason, reviewed_by, reviewed_at` and emits
one `audit_logs` row per real change (the `WHEN` clause filters out no-op
UPDATEs):

```sql
EXECUTE FUNCTION log_audit(
  'account_approval.status_changed',
  'status,rejection_reason,reviewed_by,reviewed_at',
  'user_id'
);
```

The `target_id` in the resulting `audit_logs` row is the affected user's UUID,
not the synthetic `id` of the request row.

Contract reference:
`../../specs/005-auth-profile/contracts/account-approval-audit-trigger.md`.
