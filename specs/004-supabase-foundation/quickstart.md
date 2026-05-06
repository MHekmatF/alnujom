# Phase 4 Quickstart — Supabase Foundation Manual Verification

A runnable recipe for a reviewer (human or AI agent) to confirm Phase 4 is correctly applied to the remote Supabase project. Per the durable no-new-tests rule, every step is a manual SQL query (issued via Supabase MCP `execute_sql`, or pasted into Supabase Studio's SQL editor) plus a Flutter app launch on the Infinix Note 8 reference device. There are no automated tests in this phase.

**Prerequisites**:

- The `004-supabase-foundation` branch is checked out at the commit being verified.
- The six Phase 4 migrations have been applied to the remote Supabase project via Supabase MCP `apply_migration` in order:
  - `20260506120001_init_enums`
  - `20260506120002_create_profiles`
  - `20260506120003_create_user_preferences`
  - `20260506120004_create_audit_logs`
  - `20260506120005_enable_rls_default`
  - `20260506120006_enable_vault`
- The Flutter additions (`lib/shared/domain/entities/profile.dart`, `lib/shared/domain/entities/user_preferences.dart`, `lib/shared/domain/value_objects/account_status.dart`, `lib/shared/domain/value_objects/publisher_status.dart`, the updated `lib/core/network/supabase_client_wrapper_impl.dart`) are present.

## Session terminology

- **"Privileged session"**: a Supabase MCP `execute_sql` call WITHOUT any role override. Runs as the project's `postgres` superuser-equivalent. The R-12 `enforce_profile_status_admin_only` trigger bypasses for this session via the `current_user IN ('postgres', 'supabase_admin', 'service_role', 'supabase_auth_admin')` check.
- **"Authenticated session for `<id>`"**: a single `execute_sql` call wrapped as:
  ```sql
  BEGIN;
  SELECT set_config('request.jwt.claims',
    json_build_object('sub','<id>','role','authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  <verification SQL>;
  ROLLBACK;
  ```
  **Why one call**: Supabase MCP `execute_sql` runs each call as a fresh session — `SET LOCAL ROLE` and `set_config(..., true)` (transaction-scoped) do NOT persist between calls. Multi-statement wrap is mandatory.
- **"Anonymous session"**: same wrap shape but `SET LOCAL ROLE anon;` with no `set_config` (anon has no JWT claims).

Throughout this recipe, two UUID placeholders threaded through the steps:

- `$TEST_ID` — captured in **Step 4** and reused in Steps 5, 7, 8, 8a, 9-12, 16, 20.
- `$OTHER_ID` — captured in **Step 7 setup** (a second test user) and reused in Steps 7, 8, 16, 20.

If you lose either UUID between steps (e.g., a context reset), re-run Step 4 / Step 7 setup to capture fresh ones; subsequent verifications still work on the new IDs.

---

## Step 1 — Confirm the migrations applied cleanly

Via Supabase MCP `list_migrations`, confirm the six Phase 4 filenames are present:

```
20260506120001_init_enums
20260506120002_create_profiles
20260506120003_create_user_preferences
20260506120004_create_audit_logs
20260506120005_enable_rls_default
20260506120006_enable_vault
```

(Plus the pre-existing `00000000000000_init_extensions` from Phase 1.)

Via Supabase MCP `list_tables` (with `schemas: ["public"]`), confirm the three new tables exist: `profiles`, `user_preferences`, `audit_logs`.

**Pass criteria** (SC-001):

- Seven migration filenames total (1 pre-existing + 6 Phase 4), no duplicates.
- All three tables present in `public`.

---

## Step 2 — Confirm RLS is enabled on every Phase 4 table

```sql
SELECT relname, relrowsecurity
  FROM pg_class
 WHERE relname IN ('profiles', 'user_preferences', 'audit_logs')
   AND relnamespace = 'public'::regnamespace;
```

**Pass criteria** (SC-001, FR-005): `relrowsecurity = true` for all three rows.

---

## Step 3 — Confirm every §6.3 enum exists

```sql
SELECT typname FROM pg_type
 WHERE typname IN (
   'account_status_enum', 'publisher_status_enum',
   'listing_status_enum', 'inquiry_status_enum', 'report_status_enum',
   'listing_purpose_enum', 'property_type_enum',
   'location_visibility_enum', 'report_reason_enum'
 )
 ORDER BY typname;
```

**Pass criteria** (FR-011, Q3): All nine enum types present.

---

## Step 4 — Confirm the auto-provision trigger creates BOTH rows

This step also exercises the spec's "manually-inserted auth user" edge case — the trigger MUST fire regardless of insert source.

Privileged session:

```sql
INSERT INTO auth.users (id, email, encrypted_password, role, aud, instance_id)
  VALUES (gen_random_uuid(),
          'phase4-quickstart@example.com',
          crypt('test', gen_salt('bf')),
          'authenticated',
          'authenticated',
          '00000000-0000-0000-0000-000000000000'::uuid)
  RETURNING id;
-- Note the returned UUID, call it $TEST_ID.
```

Then verify both downstream rows:

```sql
SELECT user_id, account_status, publisher_status FROM profiles WHERE user_id = '$TEST_ID';
SELECT user_id, locale, theme_mode, display_currency, notifications_enabled
  FROM user_preferences WHERE user_id = '$TEST_ID';
```

**Pass criteria** (SC-003, US 2 acceptance scenario 1, FR-004, Q1):

- `profiles` row: `account_status = 'pending'`, `publisher_status = 'pending'`.
- `user_preferences` row: `locale = 'ar'`, `theme_mode = 'system'`, `display_currency = 'SYP'`, `notifications_enabled = true`.

---

## Step 5 — Confirm the auto-provision trigger is idempotent under retry

The signup-race edge case can manifest two ways: (a) the `auth.users` PK rejects the duplicate before the trigger fires, or (b) the trigger function is invoked twice with the same `NEW.id`. Path (a) is the realistic production case; path (b) tests the trigger's `ON CONFLICT DO NOTHING` defense.

Privileged session — path (a):

```sql
INSERT INTO auth.users (id, email, encrypted_password, role, aud, instance_id)
  VALUES ('$TEST_ID'::uuid,
          'phase4-retry@example.com',
          crypt('test', gen_salt('bf')),
          'authenticated',
          'authenticated',
          '00000000-0000-0000-0000-000000000000'::uuid)
  ON CONFLICT (id) DO NOTHING;
SELECT COUNT(*) FROM profiles         WHERE user_id = '$TEST_ID';
SELECT COUNT(*) FROM user_preferences WHERE user_id = '$TEST_ID';
```

**Pass criteria**: both COUNTs = 1. The PK rejected the duplicate `auth.users` insert; the system as a whole maintains the one-profile + one-preferences invariant.

(Path (b) — direct trigger function invocation — is not exercised in Phase 4 quickstart because it would require constructing a synthetic NEW row inside an EXECUTE call; the `ON CONFLICT DO NOTHING` clauses inside `handle_new_auth_user()` are inspectable in `20260506120003_create_user_preferences.sql` and are reviewed at code-review time.)

---

## Step 6 — Confirm anonymous reads return zero rows

Anonymous session (single `execute_sql` call):

```sql
BEGIN;
SET LOCAL ROLE anon;
SELECT
  (SELECT COUNT(*) FROM profiles)         AS profiles_count,
  (SELECT COUNT(*) FROM user_preferences) AS prefs_count,
  (SELECT COUNT(*) FROM audit_logs)       AS audit_count;
ROLLBACK;
```

**Pass criteria** (SC-004, FR-005, US 2 acceptance scenario 3): all three counts return 0.

---

## Step 7 — Confirm cross-user reads are blocked

Setup — create a second test auth user via privileged session and capture the UUID as `$OTHER_ID`:

```sql
INSERT INTO auth.users (id, email, encrypted_password, role, aud, instance_id)
  VALUES (gen_random_uuid(),
          'phase4-other@example.com',
          crypt('test', gen_salt('bf')),
          'authenticated',
          'authenticated',
          '00000000-0000-0000-0000-000000000000'::uuid)
  RETURNING id;
```

Verify — single `execute_sql` call as `$TEST_ID`:

```sql
BEGIN;
SELECT set_config('request.jwt.claims',
  json_build_object('sub','$TEST_ID','role','authenticated')::text, true);
SET LOCAL ROLE authenticated;

SELECT
  (SELECT COUNT(*) FROM profiles         WHERE user_id = '$TEST_ID')  AS own_profile,
  (SELECT COUNT(*) FROM user_preferences WHERE user_id = '$TEST_ID')  AS own_prefs,
  (SELECT COUNT(*) FROM profiles         WHERE user_id = '$OTHER_ID') AS other_profile,
  (SELECT COUNT(*) FROM user_preferences WHERE user_id = '$OTHER_ID') AS other_prefs;
ROLLBACK;
```

**Pass criteria** (SC-005, US 2 acceptance scenario 2): `own_profile = 1`, `own_prefs = 1`, `other_profile = 0`, `other_prefs = 0`.

---

## Step 8 — Confirm self-write works, cross-user write fails (non-status fields)

Single `execute_sql` call as `$TEST_ID`:

```sql
BEGIN;
SELECT set_config('request.jwt.claims',
  json_build_object('sub','$TEST_ID','role','authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Self-update non-status field — must succeed:
UPDATE profiles SET full_name = 'Test User A' WHERE user_id = '$TEST_ID' RETURNING user_id;

-- Cross-user update — must affect 0 rows (RLS blocks):
UPDATE profiles SET full_name = 'Hacker' WHERE user_id = '$OTHER_ID' RETURNING user_id;
ROLLBACK;
```

**Pass criteria** (US 2 acceptance scenario 5, FR-006 row-level): self-update returns one row; cross-user update returns zero rows. (The ROLLBACK ensures neither change persists; the test verifies policy behavior, not data state.)

---

## Step 8a — Confirm self-elevation of status is blocked (R-12, FR-006 column-level)

This step verifies the BEFORE-UPDATE trigger introduced in R-12. A user CANNOT self-update `account_status` or `publisher_status`, even though the row-level RLS policy `profiles_update_self` would otherwise allow it.

Single `execute_sql` call as `$TEST_ID`:

```sql
BEGIN;
SELECT set_config('request.jwt.claims',
  json_build_object('sub','$TEST_ID','role','authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Attempt self-elevation — must FAIL with SQLSTATE 42501.
UPDATE profiles SET account_status = 'approved' WHERE user_id = '$TEST_ID';

ROLLBACK;
```

**Pass criteria** (R-12, FR-006 column-level enforcement, Constitution VIII):

- The UPDATE raises an exception.
- The error code is `42501` (`insufficient_privilege`).
- The message contains `'Only admins can change account_status or publisher_status'`.
- After the rollback, a privileged read of `$TEST_ID`'s `account_status` is unchanged from its pre-Step-8a value.

---

## Step 9 — Confirm the audit trigger fires on `account_status` changes

Privileged session (the R-12 enforce trigger bypasses for this role):

```sql
UPDATE profiles SET account_status = 'approved' WHERE user_id = '$TEST_ID';

SELECT actor_user_id, action, target_type, target_id, before_state, after_state
  FROM audit_logs
 WHERE target_type = 'profiles' AND target_id = '$TEST_ID'
 ORDER BY created_at DESC LIMIT 1;
```

**Pass criteria** (SC-006, US 3 acceptance scenario 1, FR-009, FR-010):

- Exactly one matching row.
- `action = 'profile.status_changed'`.
- `target_type = 'profiles'`, `target_id = '$TEST_ID'` (resolved via `to_jsonb(NEW) ->> 'user_id'` per `TG_ARGV[2]`).
- `before_state` JSON contains `"account_status":"pending"`.
- `after_state` JSON contains `"account_status":"approved"`.

---

## Step 10 — Confirm the audit trigger does NOT fire on unrelated changes

Privileged session:

```sql
UPDATE profiles SET full_name = 'Different Name' WHERE user_id = '$TEST_ID';
SELECT COUNT(*) FROM audit_logs WHERE target_type = 'profiles' AND target_id = '$TEST_ID';
```

**Pass criteria** (R-04 `IS DISTINCT FROM` filter): COUNT unchanged from Step 9 (still 1, not 2).

---

## Step 11 — Confirm `audit_logs` rejects client writes

Authenticated session (single `execute_sql`, three statements wrapped):

```sql
BEGIN;
SELECT set_config('request.jwt.claims',
  json_build_object('sub','$TEST_ID','role','authenticated')::text, true);
SET LOCAL ROLE authenticated;

-- Each MUST fail or affect 0 rows:
INSERT INTO audit_logs (action, target_type, target_id) VALUES ('hacker.try', 'profiles', '$TEST_ID');
UPDATE audit_logs SET action = 'tampered' WHERE target_type = 'profiles';
DELETE FROM audit_logs WHERE target_type = 'profiles';
ROLLBACK;
```

Repeat with `SET LOCAL ROLE anon;` (omit the `set_config`).

**Pass criteria** (SC-007, FR-008, US 3 acceptance scenario 2): every client-side INSERT/UPDATE/DELETE attempt fails or affects 0 rows; the privileged-session COUNT from Steps 9/10 is unchanged afterward.

---

## Step 12 — Confirm `audit_logs` reads are blocked for normal users

Authenticated session as `$TEST_ID`:

```sql
BEGIN;
SELECT set_config('request.jwt.claims',
  json_build_object('sub','$TEST_ID','role','authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT COUNT(*) FROM audit_logs WHERE target_id = '$TEST_ID';
ROLLBACK;
```

**Pass criteria** (US 3 acceptance scenario 3): COUNT = 0. Even the user whose status changed cannot read the audit row from their own session.

---

## Step 13 — Confirm the placeholder admin predicate evaluates to FALSE

Three separate `execute_sql` calls:

```sql
-- Call 1 (privileged):
SELECT current_user_is_admin();

-- Call 2 (authenticated):
BEGIN;
SELECT set_config('request.jwt.claims',
  json_build_object('sub','$TEST_ID','role','authenticated')::text, true);
SET LOCAL ROLE authenticated;
SELECT current_user_is_admin();
ROLLBACK;

-- Call 3 (anon):
BEGIN;
SET LOCAL ROLE anon;
SELECT current_user_is_admin();
ROLLBACK;
```

**Pass criteria** (R-05): all three return `false`.

---

## Step 14 — Confirm `pgsodium` and Vault scaffolding are in place

```sql
-- (1) extension
SELECT extname FROM pg_extension WHERE extname = 'pgsodium';

-- (2) function — using pg_get_function_identity_arguments (proargtypes::regtype[] doesn't cast directly):
SELECT proname,
       pg_get_function_identity_arguments(oid) AS args,
       prorettype::regtype AS return_type,
       prosecdef,
       provolatile
  FROM pg_proc WHERE proname = 'app_vault_secret';

-- (3) missing-name returns NULL without error
SELECT app_vault_secret('does_not_exist') AS result;
```

**Pass criteria** (SC-009, SC-010, FR-012):

- Query 1: 1 row.
- Query 2: 1 row with `args = 'p_name text'`, `return_type = 'text'`, `prosecdef = true`, `provolatile = 's'`.
- Query 3: NULL (no error).

---

## Step 15 — Confirm zero application-level Vault secrets

```sql
SELECT COUNT(*) FROM vault.secrets;
```

**Pass criteria** (SC-011, FR-013): the count is 0 (or matches Supabase's platform-managed baseline; the application-level count attributable to Phase 4 is exactly 0).

---

## Step 16 — Confirm uniqueness on `username`/`phone` allows multiple NULLs

`$TEST_ID` and `$OTHER_ID` both have `username IS NULL` and `phone IS NULL` from auto-provision. Privileged session:

```sql
SELECT COUNT(*) FROM profiles WHERE username IS NULL;
SELECT COUNT(*) FROM profiles WHERE phone    IS NULL;
```

Then test non-NULL collision:

```sql
UPDATE profiles SET username = 'shared_handle' WHERE user_id = '$TEST_ID';
-- Should succeed; then:
UPDATE profiles SET username = 'shared_handle' WHERE user_id = '$OTHER_ID';
-- Should fail with "duplicate key value violates unique constraint".
```

Roll back:

```sql
UPDATE profiles SET username = NULL WHERE user_id IN ('$TEST_ID', '$OTHER_ID');
```

**Pass criteria** (Q4): both NULL counts ≥ 2; second non-NULL UPDATE fails; rollback restores NULL state.

---

## Step 17 — Confirm the Flutter app builds and launches on the reference device

On the developer machine:

```text
flutter clean
flutter pub get
flutter analyze   # zero issues
```

Then deploy to the Infinix Note 8 (Helio G80, Android 10/11):

```text
flutter run --release -d <device-id>
# OR
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Walk Phase 1/2/3 surfaces — first launch in Arabic with RTL, theme toggle, locale toggle, Theme Gallery — and confirm everything still works.

**Pass criteria** (SC-012):

- `flutter analyze` reports zero issues.
- App launches without error.
- Phase 1/2/3 surfaces behave identically to pre-Phase-4 state.
- The auth-state listener is subscribed (visible in `adb logcat | Select-String 'AuthState'` on app start; first event is `signedOut`).

---

## Step 18 — Confirm domain-layer entities don't import Supabase

```text
Get-ChildItem lib/shared/domain -Recurse -Filter *.dart |
  Select-String -Pattern 'package:supabase_flutter|lib/data|features/.*/data'
```

**Pass criteria** (FR-017, Constitution IX): zero matches across `profile.dart`, `user_preferences.dart`, `account_status.dart`, `publisher_status.dart`.

---

## Step 19 — Confirm every backend artifact has a checked-in `.sql` source

Walk every Phase 4 artifact via the queries in tasks.md T041 and confirm each has a corresponding `.sql` definition in `supabase/migrations/` or `supabase/policies/`:

| Artifact | Repo source |
|---|---|
| Tables `profiles`, `user_preferences`, `audit_logs` | `0002`, `0003`, `0004` migrations |
| Functions `set_updated_at`, `current_user_is_admin`, `enforce_profile_status_admin_only`, `handle_new_auth_user`, `log_audit`, `app_vault_secret` | `0002` (first three), `0003`, `0004`, `0006` |
| Triggers `trg_profiles_set_updated_at`, `trg_profiles_enforce_status_admin_only`, `trg_user_preferences_set_updated_at`, `trg_auth_users_handle_new`, `trg_profiles_audit_status` | `0002`, `0002`, `0003`, `0003`, `0004` |
| Enum types (9) | `0001` |
| RLS policies (9 total: 4 profiles + 4 user_preferences + 1 audit_logs) | `supabase/policies/*.sql` (inlined into `0005`) |
| `pgsodium` extension | `0006` |

**Pass criteria** (SC-008, FR-014): every remote-side artifact has a matching repo definition.

---

## Step 20 — Cleanup the test data

Privileged session:

```sql
DELETE FROM auth.users WHERE id IN ('$TEST_ID', '$OTHER_ID');
-- The ON DELETE CASCADE FK propagates to profiles and user_preferences.
-- audit_logs rows persist (intentional — append-only); actor_user_id is set to NULL
-- by the ON DELETE SET NULL FK on audit_logs.actor_user_id.
```

**Pass criteria**: `SELECT` from `profiles`/`user_preferences` for either id returns 0 rows; `audit_logs` rows for those `target_id`s remain.

---

## Summary mapping

| Spec criterion | Quickstart step |
|---|---|
| SC-001 | Step 1, 2 |
| SC-002 | Implicit (Supabase migration tracker; tasks.md T042 verifies idempotent re-apply) |
| SC-003 | Step 4 |
| SC-004 | Step 6 |
| SC-005 | Step 7 |
| SC-006 | Step 9 |
| SC-007 | Step 11 |
| SC-008 | Step 19 |
| SC-009 | Step 14 |
| SC-010 | Step 14 |
| SC-011 | Step 15 |
| SC-012 | Step 17 |
| SC-013 | Phase 5 / Phase 6 review time (no Phase 4 step); Step 13 proves the helper exists. |
| FR-004, FR-019, FR-020, Q1, Q4 | Steps 4, 5, 16 |
| FR-005, FR-007, FR-008 | Steps 2, 6, 11 |
| FR-006 (row-level) | Step 8 |
| FR-006 (column-level / R-12) | Step 8a |
| FR-009, FR-010 | Steps 9, 10 |
| FR-011, Q3 | Step 3 |
| FR-012, FR-013 | Steps 14, 15 |
| FR-014 | Step 19 |
| FR-016 | Step 17 |
| FR-017 | Step 18 |
| Q2 | Step 4 (a `\d profiles` inspection confirms no `preferred_language`/`preferred_currency`) |
| Q5 | Steps 1–16 are all run via Supabase MCP `execute_sql` against the remote project |

If every step passes, Phase 4 is ready for the squash-merge per the Git workflow contract.
