# Contract: Auto-Provision Trigger

**Owner**: Phase 4 (`supabase/migrations/20260506120003_create_user_preferences.sql` defines the function and trigger).
**Consumers**: Phase 5 (auth flow assumes a profile exists immediately after signup); every phase that reads `profiles` or `user_preferences` for an authenticated user.
**Stability**: Stable — the function body and trigger declaration MUST NOT change after Phase 4 ships. Adding new auto-provisioned tables (e.g., a future `notification_preferences`) requires extending this function in the same phase that introduces the new table; the function's current responsibilities remain unchanged.

---

## Purpose

Whenever a row is inserted into `auth.users`, exactly one matching row appears in `profiles` AND exactly one matching row appears in `user_preferences`, atomically, regardless of how the insert originated (signup, fixture, admin import).

## Function

```
handle_new_auth_user() RETURNS TRIGGER
```

- **Language**: PL/pgSQL
- **Security**: `SECURITY DEFINER`
- **search_path**: `SET search_path = public`
- **Trigger event**: `AFTER INSERT ON auth.users FOR EACH ROW`

## Side effects

For each `auth.users` insert (`NEW.id` available):

1. `INSERT INTO profiles (user_id, account_status, publisher_status) VALUES (NEW.id, 'pending', 'pending') ON CONFLICT (user_id) DO NOTHING;`
2. `INSERT INTO user_preferences (user_id, locale, theme_mode, display_currency, notifications_enabled) VALUES (NEW.id, 'ar', 'system', 'SYP', TRUE) ON CONFLICT (user_id) DO NOTHING;`

Both inserts are within the same statement-level transaction. A failure on either rolls back the whole `auth.users` insert.

## Invariants

- For every `auth.users.id` value that exists, there is **exactly one** `profiles` row and **exactly one** `user_preferences` row with the same `user_id`. Either both exist or neither does.
- A retried signup (same `auth.users.id` inserted twice) does NOT produce duplicate `profiles` or `user_preferences` rows. Both `ON CONFLICT DO NOTHING` clauses absorb the retry.
- A `profiles` row inserted directly without a matching `auth.users` row fails the FK constraint. `profiles` cannot exist without an auth user.
- A `user_preferences` row inserted directly without a matching `auth.users` row fails the FK constraint.

## Default values written

| Table | Column | Default written |
|---|---|---|
| `profiles` | `account_status` | `'pending'` |
| `profiles` | `publisher_status` | `'pending'` |
| `profiles` | (other identity columns) | NULL or column-level default |
| `user_preferences` | `locale` | `'ar'` |
| `user_preferences` | `theme_mode` | `'system'` |
| `user_preferences` | `display_currency` | `'SYP'` |
| `user_preferences` | `notifications_enabled` | `TRUE` |

## Audit emission

The auto-provision trigger does NOT emit an `audit_logs` row. The `profiles` audit trigger fires on `UPDATE OF account_status, publisher_status` only. Initial `pending` state is implicit and not interesting to audit.

## Verification (Phase 4 quickstart)

```sql
-- Insert a synthetic auth.users row (privileged session via Supabase MCP execute_sql)
INSERT INTO auth.users (id, email, encrypted_password, role)
  VALUES (gen_random_uuid(), 'phase4-test@example.com', crypt('test', gen_salt('bf')), 'authenticated')
  RETURNING id;

-- Confirm both downstream rows exist
SELECT user_id, account_status, publisher_status FROM profiles WHERE user_id = '<id>';
SELECT user_id, locale, theme_mode, display_currency, notifications_enabled FROM user_preferences WHERE user_id = '<id>';

-- Idempotency check: insert again with the same id
INSERT INTO auth.users (id, email, encrypted_password, role)
  VALUES ('<same-id>', 'phase4-retry@example.com', crypt('test', gen_salt('bf')), 'authenticated')
  ON CONFLICT (id) DO NOTHING;
SELECT COUNT(*) FROM profiles WHERE user_id = '<id>';      -- expect 1
SELECT COUNT(*) FROM user_preferences WHERE user_id = '<id>'; -- expect 1
```
