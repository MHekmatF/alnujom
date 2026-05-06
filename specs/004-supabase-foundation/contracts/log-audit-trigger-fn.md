# Contract: `log_audit()` Reusable Audit Trigger Function

**Owner**: Phase 4 (`supabase/migrations/20260506120004_create_audit_logs.sql` defines the function).
**Consumers**: Every phase that has an audit-worthy table — Phase 4 (`profiles` status), Phase 5 (`account_approval_requests`), Phase 6 (`roles`, `role_permissions`, `user_roles`), Phase 7 (Edge Functions calling out for non-trigger paths), Phase 8/9 (location/currency admin actions), Phase 10/11/12 (listing lifecycle), Phase 18 (reports/moderation), Phase 19 (agency status), Phase 21 (ads).
**Stability**: **Stable across the entire v1 lifecycle.** This function's body and signature MUST NOT change after Phase 4 ships. Later phases only attach new triggers with different `TG_ARGV` values.

---

## Purpose

A single PL/pgSQL function that any later trigger can attach to a target table to write a Constitution-VII-compliant audit-log row. The contract gives every audit-relevant action across the v1 product the same shape — actor, action key, target table, target id, before/after JSON, timestamp.

## Function

```
log_audit() RETURNS TRIGGER
```

- **Language**: PL/pgSQL
- **Security**: `SECURITY DEFINER` (needs to write `audit_logs` regardless of the calling session's RLS posture).
- **search_path**: `SET search_path = public`.

## Trigger argument convention

Each trigger that uses `log_audit()` passes 2 or 3 `TG_ARGV` strings:

| Index | Name | Type | Required | Meaning |
|---|---|---|---|---|
| 0 | `action_key` | TEXT | YES | The audit-action identifier. Convention: `<table>.<verb>` (e.g., `profile.status_changed`, `role.permission_added`, `listing.approved`). |
| 1 | `column_list` | TEXT | YES | Comma-separated list of column names to capture in `before_state`/`after_state`. Empty string means "no columns" (function still emits a row with NULL JSON, useful for INSERT/DELETE-only audits where the row identity is the relevant fact). The literal `'*'` means "all columns of NEW/OLD" — use sparingly. |
| 2 | `pk_column` | TEXT | NO | The primary-key column name of the target table. **Defaults to `'id'`** when omitted. Phase 4's `profiles` trigger MUST pass `'user_id'` because `profiles.user_id` is the PK. Tables whose PK is named `id` (most later phases) MAY omit this arg. |

## Behavior by `TG_OP`

### `INSERT`

- `before_state` = `'null'::jsonb`.
- `after_state` = JSONB object built from `NEW`, restricted to columns in `column_list` (or all columns if `column_list = '*'`).
- Always emits one `audit_logs` row.

### `UPDATE`

- For each column in `column_list`, evaluate `OLD.col IS DISTINCT FROM NEW.col`.
  - If **none** of the listed columns changed → skip the insert (return NEW). This is the audit-noise filter.
  - If **at least one** changed → emit one `audit_logs` row.
- `before_state` = JSONB object built from `OLD`, restricted to `column_list`.
- `after_state` = JSONB object built from `NEW`, restricted to `column_list`.

### `DELETE`

- `before_state` = JSONB object built from `OLD`, restricted to `column_list`.
- `after_state` = `'null'::jsonb`.
- Always emits one `audit_logs` row.

## Row written

For each emission, exactly one row is inserted into `audit_logs`:

| Column | Source |
|---|---|
| `id` | `gen_random_uuid()` (column default). |
| `actor_user_id` | `auth.uid()` — NULL when the trigger fires outside a session context (e.g., a server-side fixture, a scheduled job). |
| `action` | `TG_ARGV[0]`. |
| `target_type` | `TG_TABLE_NAME` (the table the trigger is attached to). |
| `target_id` | `to_jsonb(NEW or OLD) ->> COALESCE(TG_ARGV[2], 'id')`. Table-agnostic: the function reads the PK column name from `TG_ARGV[2]` (defaulting to `'id'`), then extracts that column's value from a JSONB-converted row image. Works for any PK name without hardcoding column references in the function body. |
| `before_state` | JSONB per the rules above. |
| `after_state` | JSONB per the rules above. |
| `ip` | NULL in Phase 4. Edge Functions populate from Phase 7+ via `pg_settings.request.headers` / `current_setting('request.headers', true)`. |
| `user_agent` | Same as `ip`. |
| `created_at` | `now()` (column default). |

## Returns

- `NEW` for `INSERT` and `UPDATE`.
- `OLD` for `DELETE`.

## Phase 4's concrete trigger

```sql
CREATE TRIGGER trg_profiles_audit_status
  AFTER UPDATE OF account_status, publisher_status ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION log_audit('profile.status_changed', 'account_status,publisher_status', 'user_id');
```

The third arg `'user_id'` is the PK column name (per R-04). This is the only trigger that uses `log_audit()` in Phase 4. Later phases attach more.

## How later phases attach (illustrative)

```sql
-- Phase 5 (account_approval_requests, PK = id → omit TG_ARGV[2])
CREATE TRIGGER trg_aar_audit_decision
  AFTER UPDATE OF status ON account_approval_requests
  FOR EACH ROW
  EXECUTE FUNCTION log_audit('account_approval.decision', 'status,reason');

-- Phase 12 (listings, PK = id → omit TG_ARGV[2])
CREATE TRIGGER trg_listings_audit_status
  AFTER UPDATE OF status ON listings
  FOR EACH ROW
  EXECUTE FUNCTION log_audit('listing.status_changed', 'status');

-- Phase 19 (agency_members, PK = id, but if a phase ever uses a composite-key
-- equivalent or a non-id PK, pass the PK column name explicitly)
CREATE TRIGGER trg_agency_members_audit
  AFTER UPDATE ON agency_members
  FOR EACH ROW
  EXECUTE FUNCTION log_audit('agency.member_role_changed', 'role', 'id');
```

In every case, the **function body** is unchanged; only the trigger declaration is new.

## What MUST NOT happen

- Later phases MUST NOT redefine `log_audit()`. If a later requirement cannot be expressed via the existing `TG_ARGV` convention (e.g., capturing a computed value, not a raw column), the function gains a new `TG_ARGV` slot via a forward-compatible patch in the same spec — but the existing two-arg behavior is preserved.
- The function MUST NOT be `SECURITY INVOKER` — `audit_logs` writes from a non-admin session would fail RLS otherwise.

## Verification (Phase 4 quickstart)

```sql
-- 1. Update a profile's account_status (privileged session via Supabase MCP execute_sql).
--    The R-12 enforce_profile_status_admin_only trigger bypasses this check for
--    privileged sessions; the AFTER trigger trg_profiles_audit_status fires.
UPDATE profiles SET account_status = 'approved' WHERE user_id = '<test-id>';

-- 2. Confirm exactly one audit_logs row exists for the change.
SELECT actor_user_id, action, target_type, target_id, before_state, after_state, created_at
  FROM audit_logs
  WHERE target_type = 'profiles' AND target_id = '<test-id>'
  ORDER BY created_at DESC LIMIT 1;
-- Expect: action      = 'profile.status_changed'
--         target_id   = '<test-id>'  (resolved via to_jsonb(NEW)->>'user_id' per TG_ARGV[2])
--         before_state = {"account_status":"pending","publisher_status":"pending"}
--         after_state  = {"account_status":"approved","publisher_status":"pending"}

-- 3. Update an unrelated column; confirm NO new audit_logs row
UPDATE profiles SET full_name = 'Test User' WHERE user_id = '<test-id>';
SELECT COUNT(*) FROM audit_logs WHERE target_type = 'profiles' AND target_id = '<test-id>';
-- Expect: still 1 (full_name is not in the captured-column list).

-- 4. Confirm no client-write policy on audit_logs allows an INSERT
SET LOCAL ROLE authenticated;
INSERT INTO audit_logs (action, target_type, target_id) VALUES ('hacker.try', 'profiles', '<id>');
-- Expect: error / zero rows affected.
```
