# Quickstart — Auth & Profile (Phase 5)

End-to-end manual verification recipe. A reviewer or new agent runs these steps top-to-bottom against the remote Supabase project + the Flutter app on the reference Infinix Note 8 device, and confirms each expected result. No automated tests are introduced (per the durable no-new-tests rule); every check is a Supabase MCP call or a UI walk-through.

> **Prerequisite**: Phase 4 has been applied to the remote Supabase project (the six `20260506120001..06` migrations + the policy bundling + the Vault scaffolding). Phase 1's auth-state listener is wired (Phase 4 R-09).

> **Convention for SQL verifications**: every "Supabase MCP `execute_sql`" step assumes the call uses `mcp__plugin_supabase_supabase__execute_sql` against the project. Multi-statement RLS verifications wrap their `set_config` + `SET LOCAL ROLE` + verify queries + `RESET ROLE` in a single `execute_sql` call (per Phase 4 R-01's note that Supabase MCP runs each call in a fresh session — `SET LOCAL` does not persist across calls).

---

## Step 0 — Pre-flight Auth config (one-time per project)

The Supabase project's auth settings must be configured to match Phase 5's contract:

1. **Email confirmations OFF**. The synthetic-email mailbox doesn't exist; signup-confirmation emails are undeliverable. In the Supabase dashboard → Auth → Providers → Email → uncheck "Confirm email". (Per `spec.md` Assumptions.)
2. **Minimum password length = 8**. In the Supabase dashboard → Auth → Settings → Password → set Minimum length to 8 (per R-08, FR-001).
3. **Reset-password redirect URL** configured to a path the app handles (deep link — Phase 5's deep-link handling is light; the link can route to the app's `/reset-password-confirm` route or to a placeholder web page).

> These settings are NOT part of the migration files (Supabase exposes them as project-level config, not SQL). Document the configured values in the project's runbook.

**Verify**: open the Auth Settings page; confirm each value above.

---

## Step 1 — Apply Phase 5 migrations

Apply each migration in order via Supabase MCP `apply_migration`:

| # | Filename | Apply call |
|---|---|---|
| 1 | `20260510120001_create_account_approval_requests.sql` | `apply_migration` |
| 2 | `20260510120002_profiles_add_is_admin.sql` | `apply_migration` |
| 3 | `20260510120003_swap_admin_predicate.sql` | `apply_migration` |
| 4 | `20260510120004_profiles_vault_pii_helpers.sql` | `apply_migration` |
| 5 | `20260510120005_attach_audit_trigger_account_approval_requests.sql` | `apply_migration` |

After each `apply_migration`, run Supabase MCP `get_advisors` with `type: 'security'` and confirm no new warnings beyond the Phase 4 baseline.

**Verify** (Supabase MCP `list_migrations`): all five Phase 5 filenames appear in `supabase_migrations.schema_migrations`, sorted after the Phase 4 entries.

**Verify** (Supabase MCP `execute_sql`):

```sql
-- Account-approval table + trigger.
SELECT to_regclass('account_approval_requests');                       -- non-NULL
SELECT proname FROM pg_proc WHERE proname IN (
  'auto_create_account_approval_request',
  'approve_account_approval_request',
  'reject_account_approval_request'
);                                                                     -- 3 rows
SELECT tgname FROM pg_trigger WHERE tgname IN (
  'trg_profiles_auto_create_account_approval_request',
  'trg_account_approval_requests_set_updated_at',
  'trg_account_approval_requests_audit_status'
);                                                                     -- 3 rows

-- profiles.is_admin column.
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles' AND column_name = 'is_admin';
-- Expected: boolean, false, NO

-- current_user_is_admin body has been swapped (no longer 'SELECT FALSE;').
SELECT prosrc FROM pg_proc WHERE proname = 'current_user_is_admin';
-- Expected: includes 'is_admin FROM profiles'

-- Vault PII helpers.
SELECT proname FROM pg_proc WHERE proname IN (
  'app_vault_secret_for_self',
  'app_vault_secret_for_user',
  'app_vault_set_secret_for_self',
  'app_vault_set_secret_for_user',
  'app_vault_set_private_contact_methods_for_self'
);                                                                     -- 5 rows

-- RLS on the new table.
SELECT relname, relrowsecurity FROM pg_class
WHERE relname = 'account_approval_requests';                           -- relrowsecurity = true

-- Policies on the new table.
SELECT policyname FROM pg_policies
WHERE tablename = 'account_approval_requests'
ORDER BY policyname;
-- Expected: 3 rows: account_approval_requests_admin_read, account_approval_requests_admin_update, account_approval_requests_self_read
```

---

## Step 2 — Deploy the Edge Function

Deploy `supabase/functions/request_password_reset/index.ts` via Supabase MCP `deploy_edge_function`. Confirm via `list_edge_functions`.

**Verify** (Supabase MCP `list_edge_functions`): one row with `slug = 'request_password_reset'`, `status = 'ACTIVE'`.

**Verify** (one cURL hit, malformed body — should not leak):

```bash
curl -X POST '<project>/functions/v1/request_password_reset' \
  -H 'Authorization: Bearer <ANON_KEY>' \
  -H 'Content-Type: application/json' \
  -d '{}'
```

Expected: HTTP 400 with body `{"error":"invalid_request"}`.

---

## Step 3 — Phone-number normalization sanity (no DB or app yet — pure value-object check)

Build the Flutter app for Android. Open a Dart REPL or a debug-only test page and call `PhoneNumber.parse` on each input from the Examples table in `contracts/phone-number-value-object.md`. Confirm the canonical output matches.

Key cases:

| Input | Expected `e164` |
|---|---|
| `"+963991234567"` | `"+963991234567"` |
| `"+963 99 123 4567"` | `"+963991234567"` |
| `"0991234567"` | `"+963991234567"` |
| `"991234567"` | `"+963991234567"` |
| `"+1234567890"` | `"+1234567890"` |
| `""` | throws `phone_required` |
| `"+963 abc"` | throws `phone_invalid` |

---

## Step 4 — Bootstrap the first admin (one-time SQL)

Pick the user UUID that will be the first admin. (For initial verification you can use whichever phone you intend to register first; you'll set the flag AFTER step 5's registration so the admin is a real registered user.)

After step 5 below registers `+963991234567`, run via Supabase MCP `execute_sql`:

```sql
UPDATE profiles SET is_admin = true WHERE phone = '+963991234567';
```

Expected: 1 row updated. (If 0 rows, the registration step did not write the phone; revisit step 5.)

> Per R-19, this is the only path to bootstrap the first admin in Phase 5. Phase 7's super-admin UI ships the in-app management surface.

---

## Step 5 — Register a fresh user (US 1, FR-001..004, FR-014, FR-015, FR-018, FR-021)

On the reference Android device, fresh install (or after `adb shell pm clear <package>` to clear secure storage):

1. Launch the app. Splash → Onboarding (Arabic by default; switch to English from the locale picker if you want; the choice persists in `flutter_secure_storage` via Phase 1's wrapper).
2. Tap "Get started" at the end of onboarding. Routes to `/register`.
3. Enter:
   - Phone: `+963 99 123 4567` (the validator should accept and normalize to `+963991234567`).
   - Password: `Test1234` (8 chars; the validator should accept). Try `short` first to confirm rejection — expected: localized "Password must be at least 8 characters" error, submit blocked.
   - Optional real email: `your-test-inbox@example.com` (use an inbox you can read for step 9).
   - Full name: `Test User`.
4. Submit. Expected: app routes to `/pending` (the localized "Account pending approval" screen) within ~10 seconds.

**Verify** (Supabase MCP `execute_sql`):

```sql
SELECT user_id, account_status, publisher_status, full_name, phone, email, is_admin
FROM profiles WHERE phone = '+963991234567';
-- Expected: 1 row with account_status='pending', publisher_status='pending', full_name='Test User', email='your-test-inbox@example.com', is_admin=false.

SELECT user_id, locale, theme_mode, display_currency, notifications_enabled
FROM user_preferences
WHERE user_id = (SELECT user_id FROM profiles WHERE phone = '+963991234567');
-- Expected: 1 row. locale='ar' if you accepted the default; locale='en' if you switched in onboarding (R-11 first-sign-in handoff).

SELECT user_id, status, rejection_reason, reviewed_by, reviewed_at, created_at
FROM account_approval_requests
WHERE user_id = (SELECT user_id FROM profiles WHERE phone = '+963991234567');
-- Expected: 1 row. status='pending', rejection_reason=NULL, reviewed_by=NULL, reviewed_at=NULL.

-- Synthetic email check.
SELECT email FROM auth.users WHERE id = (SELECT user_id FROM profiles WHERE phone = '+963991234567');
-- Expected: '+963991234567@alnujom.local'
```

---

## Step 6 — Pending-screen lockout sticky (US 1 acceptance scenarios 1, 2, 7)

While the user is on `/pending`:

1. Force-close the app (swipe away from recent apps).
2. Re-open. Splash → reads the existing session → reads `profiles.account_status='pending'` → routes back to `/pending`. Expected: same screen, no home leak.
3. Sign out from the affordance on `/pending`. Routes to `/login`.
4. Sign in with `+963991234567` + `Test1234`. Expected: `/pending` again — pending status survives sign-out / sign-in cycles.
5. (Optional) Try to navigate directly to `/home` via a deep link. Expected: route guard redirects back to `/pending`.

---

## Step 7 — Account-enumeration resistance on login (FR-017)

On `/login`:

1. Submit `+963999999999` + `whatever`. Expected: localized "Invalid phone or password".
2. Submit `+963991234567` + `wrongpassword`. Expected: same localized "Invalid phone or password".

The two error copies MUST be identical — no leak about whether the phone is registered.

---

## Step 8 — Bootstrap the first admin (run Step 4's SQL now if you didn't earlier)

```sql
UPDATE profiles SET is_admin = true WHERE phone = '+963991234567';
```

The user is now both the test pending user AND the test admin. (For end-to-end coverage, register a second user `+963992345678` to be the pending-target; the first user remains the admin.)

```sql
-- Re-check the admin predicate body actually picks up is_admin.
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object(
      'sub', (SELECT user_id::text FROM profiles WHERE phone = '+963991234567'),
      'role', 'authenticated'
    )::text, true);
END $$;
SET LOCAL ROLE authenticated;
SELECT current_user_is_admin();  -- Expected: true
RESET ROLE;
```

---

## Step 9 — Admin queue + approve (US 4, FR-007..010, FR-019, SC-004)

Sign out the first user. Sign in again as the same user (phone `+963991234567`); now `account_status` is still `pending` so we need a second user to be the queue's target.

Register a second test user on the device: phone `+963992345678`, password `Test1234`, no real email. Sign out. Sign in as the first user (admin).

> Note: there is no in-app way to switch users beyond sign-out / sign-in in Phase 5.

The admin tile should now be visible in the home navigation (or wherever Phase 5's plan put it). Tap it → routes to `/admin/approvals`.

**Verify** (UI):
- Both pending users (`+963991234567` and `+963992345678`) appear in the queue. (The first user is also pending until they get approved by another admin or by privileged SQL.)
- Each row shows the phone + optional real email + timestamp.

Tap "Approve" on the second user. Expected: row disappears from the queue.

**Verify** (Supabase MCP `execute_sql`):

```sql
SELECT status, reviewed_by, reviewed_at FROM account_approval_requests
WHERE user_id = (SELECT user_id FROM profiles WHERE phone = '+963992345678');
-- Expected: status='approved', reviewed_by=<admin's user_id>, reviewed_at IS NOT NULL.

SELECT account_status FROM profiles WHERE phone = '+963992345678';
-- Expected: 'approved'.

SELECT actor_user_id, action, target_type, target_id, before_state->>'status', after_state->>'status'
FROM audit_logs
WHERE target_type = 'account_approval_requests'
  AND target_id = (SELECT user_id::text FROM profiles WHERE phone = '+963992345678')
ORDER BY created_at DESC LIMIT 1;
-- Expected: action='account_approval.status_changed', before_state.status='pending', after_state.status='approved'.
```

Sign out as admin. Sign in as `+963992345678` + `Test1234`. Expected: routes to `/home` (or, if Phase-8+ home is not yet built, to the post-approval landing slot Phase 5 owns).

---

## Step 10 — Reject with reason (US 4 acceptance scenario 3, SC-005)

Register a third test user: `+963993456789` / `Test1234` / no email. Sign out, sign in as admin. Open the queue.

Tap "Reject" on the third user. A dialog asks for a reason. Type `"Phone number could not be verified."` and confirm.

**Verify** (Supabase MCP `execute_sql`):

```sql
SELECT status, rejection_reason FROM account_approval_requests
WHERE user_id = (SELECT user_id FROM profiles WHERE phone = '+963993456789');
-- Expected: status='rejected', rejection_reason='Phone number could not be verified.'

SELECT account_status FROM profiles WHERE phone = '+963993456789';
-- Expected: 'rejected'.
```

Sign out. Sign in as `+963993456789` + `Test1234`. Expected: routes to `/rejected`; the screen displays the reviewer-supplied reason verbatim.

---

## Step 11 — Cross-user RLS holds (SC-006)

```sql
-- Simulate user_2 trying to read user_3's account_approval_requests row.
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object(
      'sub', (SELECT user_id::text FROM profiles WHERE phone = '+963992345678'),
      'role', 'authenticated'
    )::text, true);
END $$;
SET LOCAL ROLE authenticated;
SELECT * FROM account_approval_requests
WHERE user_id = (SELECT user_id FROM profiles WHERE phone = '+963993456789');
-- Expected: 0 rows (RLS suppresses the cross-user read).
RESET ROLE;
```

---

## Step 12 — `is_admin` is mutation-blocked for non-privileged callers (FR-009, SC-007)

```sql
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object(
      'sub', (SELECT user_id::text FROM profiles WHERE phone = '+963992345678'),
      'role', 'authenticated'
    )::text, true);
END $$;
SET LOCAL ROLE authenticated;
UPDATE profiles SET is_admin = true
WHERE user_id = (SELECT user_id FROM profiles WHERE phone = '+963992345678');
-- Expected: ERROR 42501 'cannot mutate is_admin from a non-privileged session'.
RESET ROLE;
```

---

## Step 13 — Profile view + edit (US 2, SC-014)

Sign in as `+963992345678` (now approved). Open profile. Verify display matches the `profiles` row.

Tap edit. Change `full_name` to `Updated Name`, set `username = test_user_42`, save. Expected: page reloads with the new values.

**Verify** (Supabase MCP `execute_sql`):

```sql
SELECT full_name, username FROM profiles WHERE phone = '+963992345678';
-- Expected: full_name='Updated Name', username='test_user_42'.
```

Try to set `username = test_user_42` from a different user (the third user, who is rejected so cannot reach the profile page — but you can simulate via `execute_sql`):

```sql
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object(
      'sub', (SELECT user_id::text FROM profiles WHERE phone = '+963993456789'),
      'role', 'authenticated'
    )::text, true);
END $$;
SET LOCAL ROLE authenticated;
UPDATE profiles SET username = 'test_user_42' WHERE user_id = auth.uid();
-- Expected: ERROR 23505 unique_violation on profiles_username_key.
RESET ROLE;
```

---

## Step 14 — Vault PII round-trip (US 5, FR-005..006, SC-008..009)

Sign in as `+963992345678`. Navigate to `/profile/private`. Enter:
- Legal name: `Hekmat Al Fanar`
- National ID: `01010101010`
- Private contact methods: `whatsapp = +963991234567`, `telegram = @hekmat`

Save. Expected: page reloads showing the saved values.

**Verify** (Supabase MCP `execute_sql`):

```sql
-- Plain SELECT on profiles must not contain the values.
SELECT * FROM profiles WHERE phone = '+963992345678';
-- Expected: no plaintext for legal_name / national_id / private_contact_methods (the columns don't exist on profiles).

-- vault.secrets has the three rows.
SELECT name FROM vault.decrypted_secrets
WHERE name LIKE 'pii.' || (SELECT user_id::text FROM profiles WHERE phone = '+963992345678') || '.%';
-- Expected: 3 rows: pii.<uuid>.legal_name, pii.<uuid>.national_id, pii.<uuid>.private_contact_methods.

-- Self-decrypt.
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object(
      'sub', (SELECT user_id::text FROM profiles WHERE phone = '+963992345678'),
      'role', 'authenticated'
    )::text, true);
END $$;
SET LOCAL ROLE authenticated;
SELECT app_vault_secret_for_self('legal_name');                                           -- 'Hekmat Al Fanar'
SELECT app_vault_secret_for_self('national_id');                                          -- '01010101010'
SELECT app_vault_secret_for_self('private_contact_methods')::jsonb;                      -- {"whatsapp": "+963991234567", "telegram": "@hekmat"}
RESET ROLE;

-- Cross-user read attempt (non-admin).
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object(
      'sub', (SELECT user_id::text FROM profiles WHERE phone = '+963993456789'),
      'role', 'authenticated'
    )::text, true);
END $$;
SET LOCAL ROLE authenticated;
SELECT app_vault_secret_for_user(
  (SELECT user_id FROM profiles WHERE phone = '+963992345678'),
  'legal_name'
);  -- Expected: NULL (silent — non-admin returns NULL).
RESET ROLE;

-- Admin read.
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object(
      'sub', (SELECT user_id::text FROM profiles WHERE phone = '+963991234567'),
      'role', 'authenticated'
    )::text, true);
END $$;
SET LOCAL ROLE authenticated;
SELECT app_vault_secret_for_user(
  (SELECT user_id FROM profiles WHERE phone = '+963992345678'),
  'legal_name'
);  -- Expected: 'Hekmat Al Fanar'.
RESET ROLE;

-- Allowlist guard.
SELECT app_vault_set_private_contact_methods_for_self('{"skype": "live:hekmat"}'::jsonb);
-- Expected: ERROR 22023 'unknown channel key: skype'.
```

---

## Step 15 — Reset password with real email (US 3, SC-010)

On `/login`, tap "Forgot password?". Enter `+963991234567` (the first user, who registered with a real email). Submit.

Expected (UI): localized "If an account exists for this phone, a reset link has been sent" message.

Check the real inbox `your-test-inbox@example.com`. Expected: a Supabase password-reset email arrives within Supabase's email-delivery SLA (typically <30 seconds for the platform's transactional emails).

Click the link, set a new password (`NewTest1234`), confirm. Sign in with the new password. Expected: success.

---

## Step 16 — Reset password without real email (US 3, SC-011)

On `/login`, tap "Forgot password?". Enter `+963992345678` (the second user, no real email). Submit.

Expected (UI): same generic message as Step 15.

**Verify** (Supabase MCP `get_logs` for `function`):
```
-- The Edge Function logs should show the lookup happened but no reset email was sent.
-- Expected: a log entry like "no email on file for phone <phone>; skipping reset" (or equivalent).
```

No reset email arrives anywhere.

---

## Step 17 — Reset password with unknown phone (FR-017 enumeration resistance)

On `/login`, tap "Forgot password?". Enter `+963990000000` (unregistered). Submit.

Expected (UI): same generic message.

The user-facing copy is identical across Steps 15, 16, 17 — no leak.

---

## Step 18 — Suspended user mid-session (Edge case, R-21)

Sign in as `+963992345678` (now approved with the new password from Step 15 if you used the same phone). Open the home screen. Switch to another app (don't sign out).

Via Supabase MCP `execute_sql`, suspend them:

```sql
UPDATE profiles SET account_status = 'suspended' WHERE phone = '+963992345678';
```

Bring the app back to the foreground. Expected (per R-21): the AuthBloc on app-resume re-reads `profiles`, observes `account_status='suspended'`, and the go_router redirect routes the user to `/suspended`.

(Note: while the app was backgrounded, no real-time push fired — that lands in Phase 22.)

---

## Step 19 — Idempotent migration apply (SC-016)

Re-apply each Phase 5 migration via Supabase MCP `apply_migration`. Expected: every call is a no-op (Supabase's migration tracker reports them already applied; the table+function+trigger are unchanged).

```sql
-- Re-check object counts unchanged.
SELECT count(*) FROM pg_proc WHERE proname IN (
  'auto_create_account_approval_request',
  'approve_account_approval_request',
  'reject_account_approval_request',
  'app_vault_secret_for_self',
  'app_vault_secret_for_user',
  'app_vault_set_secret_for_self',
  'app_vault_set_secret_for_user',
  'app_vault_set_private_contact_methods_for_self',
  'enforce_profile_status_admin_only',
  'current_user_is_admin'
);
-- Expected: 10 (no duplicates).
```

---

## Step 20 — Sign-out clears session (Edge case)

Sign out from any of the test accounts. Re-launch the app. Expected: routes to `/login` (or `/onboarding` only if you cleared `flutter_secure_storage`'s `onboarding_seen_v1` key); the previous session cannot be resumed without re-entering credentials.

---

## Cleanup

After verification, delete the test users via privileged SQL (cascades to `profiles`, `user_preferences`, `account_approval_requests`, and the user's PII secrets in `vault.secrets` — though Vault secret cleanup may need a separate sweep depending on Supabase's cascade behavior; verify with `SELECT name FROM vault.decrypted_secrets WHERE name LIKE 'pii.<deleted-uuid>.%'`):

```sql
DELETE FROM auth.users WHERE id IN (
  SELECT user_id FROM profiles
  WHERE phone IN ('+963991234567', '+963992345678', '+963993456789')
);
```

If any `vault.secrets` rows remain after the cascade, delete them via `SELECT vault.delete_secret(<secret_id>)` per the Supabase Vault API.

---

## Coverage summary

| FR | Verified by step |
|---|---|
| FR-001 | 5 (registration), 7 (enumeration), 16 (reset variant), 17 (reset unknown) |
| FR-002 | 5 (auto-provision triggers fired) |
| FR-003 | 5 (account_approval_requests row created) |
| FR-004 | 5 (auto-population trigger), 19 (idempotent re-apply) |
| FR-005 | 14 (Vault round-trip; pg_dump shape implicit) |
| FR-006 | 14 (self-read, admin-read, non-admin-blocked) |
| FR-007 | 8 (admin-bootstrap), 12 (mutation guard) |
| FR-008 | 1 (RLS+policies inspection), 11 (cross-user RLS) |
| FR-009 | 12 (is_admin mutation guard) |
| FR-010 | 9 (audit row on approve), 10 (audit row on reject) |
| FR-011 | (compile-time + 5/13 happy path) |
| FR-012 | 13 (profile view + edit) |
| FR-013 | 5 (onboarding seen + skip on subsequent launch) |
| FR-014 | 3 (phone-number normalization) |
| FR-015 | 5 (synthetic email recorded in auth.users) |
| FR-016 | 6 (pending lockout), 18 (suspension lockout) |
| FR-017 | 7, 15, 16, 17 (enumeration resistance across all paths) |
| FR-018 | 5 (registration writes locale to user_preferences) |
| FR-019 | 9, 10 (admin queue end-to-end) |
| FR-020 | 1 (Supabase MCP apply_migration), 19 (re-apply) |
| FR-021 | 1 (verify table doc files exist in supabase/docs/) |

| SC | Verified by step |
|---|---|
| SC-001 | 5 |
| SC-002 | 5 |
| SC-003 | 7 |
| SC-004 | 9 |
| SC-005 | 10 |
| SC-006 | 11 |
| SC-007 | 12 |
| SC-008 | 14 |
| SC-009 | 14 |
| SC-010 | 15 |
| SC-011 | 16 |
| SC-012 | 9 (admin-visible) + 11 (non-admin RLS-blocked) |
| SC-013 | 5 (onboarding RTL toggle) |
| SC-014 | 13 (compile-time grep + UI render) |
| SC-015 | 1 (verify swap is single CREATE OR REPLACE FUNCTION) + code review |
| SC-016 | 19 |
| SC-017 | All UI steps end-to-end |
