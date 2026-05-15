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

- Function: `enforce_profile_status_admin_only()` — Phase 5 extended the body
  to also reject `is_admin` mutations; Phase 6 removes that extension (the
  column is dropped) and the function reverts to guarding the two status columns only.
- Trigger: `trg_profiles_enforce_status_admin_only` (`BEFORE UPDATE`) — unchanged.

If a non-admin, non-privileged session attempts changes to either governed
column, the trigger raises SQLSTATE `42501`.

Privileged-role bypass list (per Phase 4 R-12, unchanged in Phase 5): `postgres`,
`supabase_admin`, `service_role`. Supabase MCP `execute_sql` runs as `postgres`
and therefore bypasses — required for the first-admin bootstrap (see
`../../specs/005-auth-profile/research.md` R-19).

Rationale references: `../../specs/004-supabase-foundation/research.md` (R-12),
`../../specs/005-auth-profile/research.md` (FR-009 extension).

## Phase 5 Admin Predicate Body Swap

`current_user_is_admin()` is the single helper every admin-gated policy across
`profiles`, `audit_logs`, and `account_approval_requests` calls. Phase 4 shipped
the placeholder body `SELECT FALSE`; Phase 5 swapped it (in
`20260510120003_swap_admin_predicate.sql` with `SET search_path = public` added in
the `20260510120006_phase5_advisor_hardening.sql` follow-up) to:

```sql
SELECT COALESCE((SELECT is_admin FROM profiles WHERE user_id = auth.uid()), FALSE);
```

**No Phase 4 policy file is edited** in Phase 5 — the central-helper invariant
(SC-015) is preserved.

## Phase 6 Changes

### `is_admin` Column Removed

Migration `20260515120007_backfill_is_admin_and_drop.sql` drops the interim
Phase 5 `is_admin` column after backfilling every prior `is_admin = TRUE` user
into `user_roles` with the `admin` role. The column no longer exists.

### `current_user_is_admin()` Second Body Swap

Phase 6 swaps `current_user_is_admin()` again via
`20260515120006_swap_admin_predicate_to_role_check.sql`. The new body is a
role-membership check:

```sql
SELECT COALESCE((
  EXISTS (
    SELECT 1 FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid()
      AND r.key IN ('admin', 'super_admin')
  )
), FALSE);
```

The same set of users (prior Phase 5 admins, now holding the `admin` role) is
admitted. **No Phase 4 or Phase 5 policy files are edited** — the
central-helper invariant (R-05) is preserved a second time.

Contract references: `../../specs/006-roles-permissions/contracts/admin-predicate-v6.md`,
`../../specs/006-roles-permissions/research.md` (R-12).

### Stacked Cross-User `profiles` Read Policy

Phase 6 stacks a second SELECT policy on `profiles` via the new file
`supabase/policies/profiles_phase6_users_view.sql` (bundled into migration 6):

| Policy | Operation | Predicate |
|---|---|---|
| `profiles_phase6_users_view` | SELECT | `current_user_has_permission('users.view')` |

Moderators and admins (who hold `users.view`) can read other users' profile
rows. Regular users only see their own row via the Phase 4 self-read policy.

Contract reference: `../../specs/006-roles-permissions/contracts/profiles-users-view-policy.md`.

### `enforce_profile_status_admin_only()` Trigger Rewrite

The Phase 5 extension that also blocked `is_admin` mutations is removed (the
column is gone). The function now only guards `account_status` and
`publisher_status`. The trigger (`trg_profiles_enforce_status_admin_only`) is
unchanged.

## Phase 5 Vault PII RPCs

Per ADR-0001 + FR-005/FR-006, `legal_name`, `national_id`, and
`private_contact_methods` are NOT plaintext columns on this table. They are
stored as per-user secrets in `vault.secrets` keyed `pii.<user_id>.<field_name>`.
The five SECURITY DEFINER helpers in
`20260510120004_profiles_vault_pii_helpers.sql` mediate every read and write:

| Function | Purpose | Auth |
|---|---|---|
| `app_vault_secret_for_self(field_name)` | Read own PII | `auth.uid()` |
| `app_vault_secret_for_user(p_user_id, field_name)` | Read another user's PII | `current_user_is_admin()` (returns NULL silently if not admin — no info leak) |
| `app_vault_set_secret_for_self(field_name, p_value)` | Write own `legal_name`/`national_id` | `auth.uid()` |
| `app_vault_set_secret_for_user(p_user_id, field_name, p_value)` | Write another user's `legal_name`/`national_id` | `current_user_is_admin()` |
| `app_vault_set_private_contact_methods_for_self(p_methods JSONB)` | Write own contact methods (typed-key allowlist) | `auth.uid()` |

`field_name` is allowlisted to `{legal_name, national_id, private_contact_methods}`.
Contact-method JSON keys are allowlisted to `{whatsapp, telegram, signal,
private_email, secondary_phone}`. Unknown values raise SQLSTATE `22023`.

`EXECUTE` is granted to `authenticated` only; `anon` is revoked
(`20260510120006_phase5_advisor_hardening.sql`).

Contract reference:
`../../specs/005-auth-profile/contracts/vault-pii-helpers.md`.

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
