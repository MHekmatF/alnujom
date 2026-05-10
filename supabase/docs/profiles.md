# profiles

## Purpose

`profiles` stores each authenticated user's server-side identity record and account
status state. It is keyed by `auth.users.id` and is created automatically when a
new auth user is inserted.

## Columns

Defined in `supabase/migrations/20260506120002_create_profiles.sql`:

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `user_id` | `UUID` | NO | — | PK, FK to `auth.users(id)` with `ON DELETE CASCADE` |
| `full_name` | `TEXT` | YES | `NULL` | |
| `username` | `TEXT` | YES | `NULL` | `UNIQUE`, NULL-distinct semantics |
| `phone` | `TEXT` | YES | `NULL` | `UNIQUE`, NULL-distinct semantics |
| `email` | `TEXT` | YES | `NULL` | |
| `avatar_url` | `TEXT` | YES | `NULL` | |
| `account_status` | `account_status_enum` | NO | `'pending'` | Admin-governed |
| `publisher_status` | `publisher_status_enum` | NO | `'pending'` | Admin-governed |
| `created_at` | `TIMESTAMPTZ` | NO | `now()` | |
| `updated_at` | `TIMESTAMPTZ` | NO | `now()` | Updated by trigger |

## Auto-Provision

`trg_auth_users_handle_new` on `auth.users` executes `handle_new_auth_user()` and
creates exactly one `profiles` row and one `user_preferences` row per new auth
user, using `ON CONFLICT (user_id) DO NOTHING` for idempotency.

Contract reference:
`../../specs/004-supabase-foundation/contracts/auto-provision-trigger.md`.

## RLS

RLS is enabled in `20260506120005_enable_rls_default.sql` with these policies:

- `profiles_select_self`
- `profiles_select_admin`
- `profiles_update_self`
- `profiles_update_admin`

Self access is based on `auth.uid() = user_id`. Admin-gated access uses
`current_user_is_admin()`.

## R-12 Status-Field Enforcement Trigger

Phase 4 enforces column-level admin-only control of `account_status` and
`publisher_status` with:

- Function: `enforce_profile_status_admin_only()`
- Trigger: `trg_profiles_enforce_status_admin_only` (`BEFORE UPDATE`)

If a non-admin, non-privileged session attempts status changes, the trigger raises
SQLSTATE `42501`.

Rationale reference:
`../../specs/004-supabase-foundation/research.md` (R-12).

## Audit Coverage

Status changes are audited by `trg_profiles_audit_status`:

```sql
AFTER UPDATE OF account_status, publisher_status ON profiles
EXECUTE FUNCTION log_audit('profile.status_changed', 'account_status,publisher_status', 'user_id');
```

This captures before/after JSON for status columns only.

## Q2 Omission

`profiles` intentionally does not include `preferred_language` or
`preferred_currency`. Canonical preference fields live in `user_preferences`
(`locale`, `display_currency`).
