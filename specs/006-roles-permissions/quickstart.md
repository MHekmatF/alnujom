# Phase 6 — Roles & Permissions: Quickstart Verification

End-to-end manual verification recipe for Phase 6. Run after `/speckit-implement` finishes and before squash-merging the PR.

**Prerequisites**:
- Phases 1–5 have shipped and the remote Supabase project carries the Phase 5 schema (profiles + is_admin + Vault PII + account_approval_requests).
- The reference test device (Infinix Note 8 — `user_test_device.md`) is connected via USB or wireless ADB.
- `flutter run --dart-define-from-file=.env.json` runs cleanly per `project_dart_defines.md`.
- At least two pre-Phase-6 admin users exist on the remote project (`profiles.is_admin = true`). If not, bootstrap one via `Supabase MCP execute_sql` before starting.

**Verification posture**: manual SQL via Supabase MCP `execute_sql` + Supabase MCP `get_advisors` after each migration + manual UI walk on the device. No automated tests (per `feedback_no_new_tests.md`).

---

## Step 1 — Pre-migration baseline capture

Capture the counts that will be used to verify the backfill.

```sql
-- Count of pre-Phase-6 admins (will become user_roles admin assignments).
SELECT count(*) FROM public.profiles WHERE is_admin = TRUE;
-- Save as N_pre_admin.

-- Count of all existing profiles (will become user_roles user assignments).
SELECT count(*) FROM public.profiles;
-- Save as M_profiles.

-- Capture the list of admin user_ids so we can verify each is converted.
SELECT user_id FROM public.profiles WHERE is_admin = TRUE ORDER BY user_id;
-- Save as L_admin_pre.
```

---

## Step 2 — Apply the eight Phase 6 migrations

Apply each migration in order via Supabase MCP `apply_migration`. After each, run Supabase MCP `get_advisors` and resolve any new warnings before proceeding to the next.

| # | Migration | Expected `get_advisors` warnings |
|---|-----------|--------------------------------|
| 1 | `20260515120001_create_roles.sql` | None (RLS enabled, no `SECURITY DEFINER` functions added in this migration) |
| 2 | `20260515120002_create_permissions.sql` | None |
| 3 | `20260515120003_create_role_permissions.sql` | None |
| 4 | `20260515120004_create_user_roles.sql` | One: `auto_create_user_role_for_user` is `SECURITY DEFINER` without an explicit advisor pass. Will be resolved by migration 8. |
| 5 | `20260515120005_create_permission_predicate.sql` | One: `current_user_has_permission` is `SECURITY DEFINER`. Resolved by migration 8. |
| 6 | `20260515120006_swap_admin_predicate_to_role_check.sql` | One: re-warns about `current_user_is_admin` since the body was replaced. Resolved by migration 8. |
| 7 | `20260515120007_backfill_is_admin_and_drop.sql` | None additional. |
| 8 | `20260515120008_phase6_advisor_hardening.sql` | None — this migration's purpose is to resolve the 3 warnings from migrations 4/5/6. |

After migration 8, `get_advisors` should return zero new warnings.

---

## Step 3 — Verify the seeded role catalog (US1, SC-001)

```sql
SELECT count(*) FROM public.roles WHERE is_system = TRUE;
-- Expected: 7

SELECT key FROM public.roles ORDER BY key;
-- Expected: admin, agency_admin, agent, moderator, owner, super_admin, user

SELECT display_name->>'ar' AS ar, display_name->>'en' AS en
FROM public.roles WHERE key = 'admin';
-- Expected: ar='مدير', en='Admin'
```

---

## Step 4 — Verify the seeded permission catalog (US1, SC-002)

```sql
SELECT count(*) FROM public.permissions;
-- Expected: ≥ 24

SELECT key FROM public.permissions WHERE category = 'users' ORDER BY key;
-- Expected: users.approve, users.reject, users.suspend, users.view

SELECT category, count(*) FROM public.permissions GROUP BY category ORDER BY category;
-- Expected (11 categories):
-- ads:1 agencies:3 audit:1 currencies:1 inquiries:1 listings:5 locations:1
-- reports:1 roles:5 settings:1 users:4
```

---

## Step 5 — Verify the seeded role-permission mappings (US1, SC-003)

```sql
-- Moderator: 5 rows
SELECT p.key FROM public.role_permissions rp
JOIN public.roles r ON r.id = rp.role_id
JOIN public.permissions p ON p.id = rp.permission_id
WHERE r.key = 'moderator' ORDER BY p.key;
-- Expected: listings.approve, listings.reject, listings.view_all, reports.manage, users.view

-- Admin: 17 rows
SELECT count(*) FROM public.role_permissions rp
JOIN public.roles r ON r.id = rp.role_id WHERE r.key = 'admin';
-- Expected: 17

-- Super_admin: all 24
SELECT count(*) FROM public.role_permissions rp
JOIN public.roles r ON r.id = rp.role_id WHERE r.key = 'super_admin';
-- Expected: 24

-- User / owner / agent / agency_admin: zero each
SELECT r.key, count(*) FROM public.roles r
LEFT JOIN public.role_permissions rp ON rp.role_id = r.id
WHERE r.key IN ('user', 'owner', 'agent', 'agency_admin')
GROUP BY r.key ORDER BY r.key;
-- Expected: agency_admin: 0, agent: 0, owner: 0, user: 0
```

---

## Step 6 — Verify the backfill (US2, SC-004, SC-005, SC-006)

```sql
-- SC-004: every prior admin holds the admin role.
SELECT count(DISTINCT ur.user_id) FROM public.user_roles ur
JOIN public.roles r ON r.id = ur.role_id WHERE r.key = 'admin';
-- Expected: ≥ N_pre_admin (from Step 1).

-- Verify each user_id from L_admin_pre is present
SELECT user_id FROM public.user_roles ur
JOIN public.roles r ON r.id = ur.role_id WHERE r.key = 'admin'
ORDER BY user_id;
-- Expected: includes every user_id from L_admin_pre.

-- SC-005: every profile holds the user role.
SELECT count(*) FROM public.profiles p WHERE NOT EXISTS (
  SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id
  WHERE ur.user_id = p.user_id AND r.key = 'user'
);
-- Expected: 0

-- SC-006: the column is dropped.
SELECT 1 FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'is_admin';
-- Expected: 0 rows.

SELECT is_admin FROM public.profiles LIMIT 1;
-- Expected: ERROR 42703 'column "is_admin" does not exist'
```

---

## Step 7 — Verify the body-swapped helpers (SC-008, SC-015)

```sql
-- SC-015: current_user_is_admin() body uses role check, not is_admin column.
SELECT pg_get_functiondef('public.current_user_is_admin()'::regprocedure);
-- Expected: definition contains 'user_roles ur' and 'roles r' joins; does NOT contain 'is_admin'.

-- SC-008: helper returns the right values per role.
-- For each test user (regular, moderator if you have one, admin, super_admin if you have one):
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<test-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT current_user_has_permission('users.approve');
-- For admin: TRUE
-- For moderator: FALSE
-- For regular user: FALSE
RESET ROLE;
```

---

## Step 8 — Verify the system-role immutability trigger (SC-014)

```sql
-- Renaming a system role MUST fail
UPDATE public.roles SET key = 'admin_new' WHERE key = 'admin';
-- Expected: ERROR 42501 'cannot rename system role: admin'

-- Deleting a system role MUST fail
DELETE FROM public.roles WHERE key = 'user';
-- Expected: ERROR 42501 'cannot delete system role: user'

-- Editing display_name MUST succeed
UPDATE public.roles SET display_name = display_name || '{"fr":"Test"}' WHERE key = 'admin';
-- Expected: UPDATE 1.
-- (Then revert: UPDATE public.roles SET display_name = display_name - 'fr' WHERE key = 'admin'.)
```

---

## Step 9 — Verify the cross-user `profiles` read policy (SC-009)

```sql
-- As a moderator session, cross-user SELECT MUST return the target row.
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<moderator-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT user_id, username FROM public.profiles WHERE user_id = '<another-user-uuid>';
-- Expected: 1 row.
RESET ROLE;

-- As a regular user, the same query returns zero rows.
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<regular-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT user_id, username FROM public.profiles WHERE user_id = '<another-user-uuid>';
-- Expected: 0 rows.
RESET ROLE;
```

---

## Step 10 — Verify the audit-log entries for the backfill (FR-010 + R-15)

```sql
-- Total user_role grants emitted by the backfill = N_pre_admin (admin grants) + M_profiles (user grants).
-- Note: the audit column is actor_user_id (NOT actor). The action key is 'user_role.granted' (NOT 'user_role.inserted')
-- because Phase 4's log_audit() takes the action string verbatim from TG_ARGV[0] and the Phase 6 trigger passes the
-- full key per Phase 5 convention.
SELECT count(*) FROM public.audit_logs
WHERE action = 'user_role.granted' AND actor_user_id IS NULL;
-- Expected: ≈ N_pre_admin + M_profiles (could be larger if the auto-user-role trigger fired for any new signups during verification).

-- Spot-check a row's shape:
SELECT before_state, after_state, target_id, target_type FROM public.audit_logs
WHERE action = 'user_role.granted' AND actor_user_id IS NULL LIMIT 1;
-- Expected: before_state = 'null'::jsonb; after_state has id/user_id/role_id/granted_at; target_id = after_state->>'user_id'; target_type = 'user_roles'.

-- No revoked rows yet — Phase 6 never DELETEs from user_roles.
SELECT count(*) FROM public.audit_logs WHERE action = 'user_role.revoked';
-- Expected: 0
```

---

## Step 11 — Verify the no-policy-edit invariant (SC-016)

```bash
# From a terminal on the repo root:
git diff main..HEAD -- supabase/policies/profiles_policies.sql \
                       supabase/policies/user_preferences_policies.sql \
                       supabase/policies/audit_logs_policies.sql \
                       supabase/policies/account_approval_requests_policies.sql
# Expected: zero output — none of these Phase 4 / Phase 5 policy files is edited.

# Confirm the new policy files DO appear:
git diff main..HEAD --name-only -- supabase/policies/
# Expected: includes roles_policies.sql, permissions_policies.sql, role_permissions_policies.sql,
# user_roles_policies.sql, profiles_phase6_users_view.sql — but NOT any pre-existing file.
```

---

## Step 12 — Build and launch the Flutter app on the reference device

```bash
flutter clean
flutter pub get
flutter build apk --debug --dart-define-from-file=.env.json
flutter install --device-id=<infinix-note-8-device-id>
flutter run --dart-define-from-file=.env.json --device-id=<infinix-note-8-device-id>
```

Expected: app launches cold to the splash screen → routes to login or home depending on existing session.

---

## Step 13 — Verify Phase 5 admin queue still works (US2, SC-007)

Sign in as the prior-Phase-5 admin user on the device. Open the main navigation. Tap the new "Admin" tile (introduced by Phase 6).

Expected screen flow:
1. **Main navigation** shows the "Admin" tile (visible because admin holds many admin-category permissions).
2. **Admin home page** shows one tile: "Account approvals" (the only tile shipped in Phase 6).
3. **Account approvals page** (rehosted from Phase 5 at `/admin/approvals`) shows pending requests as before.
4. Approve one pending request — confirm: `account_approval_requests.status` flips to `approved`, `profiles.account_status` flips to `approved`, and `audit_logs` emits the Phase 5 audit row.

---

## Step 14 — Verify navigation visibility per role (US4, SC-011)

| Test user role | Expected admin tile visibility |
|---|---|
| Regular `user` (only the `user` role) | NOT visible |
| `moderator` (assigned manually via Supabase MCP `execute_sql`) | Visible |
| `admin` (the prior-Phase-5 admin) | Visible |
| `super_admin` (assigned via the post-Phase-6 bootstrap SQL — see Step 18) | Visible |

For each role, sign in on the device, open the main navigation, and visually confirm the admin tile's presence or absence.

---

## Step 15 — Verify the profile page Roles section (US3, SC-012)

Sign in as each of the four test users above. Open the profile page. Scroll to the new "Roles" section.

| Test user | Roles section content |
|---|---|
| Regular `user` | One entry: "User" (en) or "مستخدم" (ar) |
| `moderator` | Two entries: "User", "Moderator" / "مستخدم", "مشرف" (alphabetical by `roles.key`) |
| `admin` | Two entries: "User", "Admin" / "مستخدم", "مدير" |
| `super_admin` | Three entries: "User", "Admin", "Super Admin" / "مستخدم", "مدير", "مدير عام" |

Toggle the device locale (Settings → System → Languages) between Arabic and English. Confirm the display names flip accordingly.

---

## Step 16 — Verify the PermissionChecker mid-session refresh (US5, SC-010)

This step exercises the FR-015 lifecycle-resume observation point.

1. Sign in on the device as a regular user (only `user` role). Confirm no admin tile.
2. Background the app (press the home button — do NOT force-quit, which would clear the session).
3. From a desktop, INSERT an `admin`-role row for this user:
   ```sql
   INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
   VALUES ('<this-user-uuid>', (SELECT id FROM public.roles WHERE key='admin'), NULL, now());
   ```
4. Foreground the app on the device. Wait 1–3 seconds.
5. **Expected**: the "Admin" tile appears in the main navigation. The profile page (if reopened) shows the new "Admin" entry.
6. Optional follow-on: tap the admin tile → admin home → "Account approvals" tile is visible → tap → admin queue loads.

---

## Step 17 — Verify the no-Supabase-import invariant (SC-019)

```bash
# From the repo root:
grep -R "package:supabase_flutter" lib/core/security/permission_checker.dart \
                                    lib/core/security/permission_keys.dart \
                                    lib/core/security/permission_catalog_repository.dart \
                                    lib/features/admin/domain/ \
                                    lib/features/profile/domain/
# Expected: zero output — none of these files imports Supabase.

# Confirm permission_catalog_repository_impl.dart DOES import Supabase (the one allowed place):
grep "package:supabase_flutter" lib/core/security/permission_catalog_repository_impl.dart
# Expected: one match.
```

---

## Step 18 — (Operational) Bootstrap the first super_admin (R-16)

This is the one-time post-Phase-6 deploy step that activates Phase 7's super-admin UI. It is intentionally NOT a migration (Q1 — Option C).

From Supabase MCP `execute_sql` running as `postgres`:

```sql
INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
VALUES (
  '<chosen-super-admin-user-uuid>',
  (SELECT id FROM public.roles WHERE key = 'super_admin'),
  NULL,
  now()
)
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Verify:
SELECT count(DISTINCT ur.user_id) FROM public.user_roles ur
JOIN public.roles r ON r.id = ur.role_id WHERE r.key = 'super_admin';
-- Expected: 1
```

Choose `<chosen-super-admin-user-uuid>` based on operational judgment — typically the project owner's user_id. Document the chosen user in the Phase 6 PR's merge commit message OR in a non-checked-in operational note (the user_id is sensitive enough that we explicitly chose NOT to commit it into a migration — R-16).

---

## Step 19 — Re-apply each migration to confirm idempotency (SC-017)

Re-apply each of the eight migrations via Supabase MCP `apply_migration` with the same names. Confirm:
- Each apply succeeds (no errors).
- Row counts in `roles`, `permissions`, `role_permissions`, `user_roles` are unchanged.
- The duplicate-tracker-row caveat (`project_supabase_mcp_apply_migration.md`) means the migration tracker gains a second row per migration; that is expected and cosmetic — the SQL itself is idempotent.

---

## Step 20 — Update CLAUDE.md + check DEFERRED.md

Confirm `CLAUDE.md` SPECKIT marker references `006-roles-permissions` (was `005-auth-profile`). If any intentional gap surfaced during implement, document it in `specs/006-roles-permissions/DEFERRED.md` (the `project_deferred_work.md` follow-up trigger).

If no DEFERRED entries: note "No deferrals — Phase 6 ships complete" in the PR body.

---

## Pass criteria

Phase 6 is verified-complete iff:
- Every step above produces the "Expected" outcome.
- Supabase MCP `get_advisors` returns zero new warnings after migration 8.
- The Phase 6 PR's diff against `supabase/policies/` shows only new files (no existing-file edits).
- The Flutter `grep` over `lib/core/security/*.dart` (excluding `permission_catalog_repository_impl.dart`) and over `lib/features/{admin,profile}/domain/` returns zero Supabase imports.
- The device walk through Steps 13–16 produces the expected UI without runtime errors.
