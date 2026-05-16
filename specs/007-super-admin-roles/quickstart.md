# Quickstart: Super-Admin Role & Permission Management

**Owner**: Phase 7 (`specs/007-super-admin-roles/`).
**Purpose**: End-to-end manual verification recipe for Phase 7. Walked by `/speckit-implement` at close-out and by `/review` before squash-merge.
**Audience**: developers, reviewers, AI agents. Self-contained; no prior session context required.

This document is the single source of truth for "does Phase 7 work end to end?". Every functional requirement (FR-001..FR-021) and every success criterion (SC-001..SC-027) is exercised by one or more steps below.

---

## Pre-flight

Before running this quickstart, confirm:

1. **Phase 6 is shipped**: the four Phase 6 catalog tables (`roles`, `permissions`, `role_permissions`, `user_roles`) exist on the remote Supabase project; the seven seeded system roles and 24 seeded permissions are present; the `current_user_has_permission` and (body-swapped) `current_user_is_admin` helpers are defined. Verify via Supabase MCP `execute_sql`:

   ```sql
   SELECT count(*) FROM public.roles WHERE is_system = true;        -- expect 7
   SELECT count(*) FROM public.permissions;                         -- expect 24
   SELECT pg_get_functiondef('public.current_user_has_permission(text)'::regprocedure) IS NOT NULL;  -- expect true
   ```

2. **Reference device ready**: Infinix Note 8 (Helio G80, 6 GB RAM, Android 10/11) per project memory `user_test_device.md`. Optional secondary device for the mid-session propagation test (US5 / SC-011).

3. **Environment file present**: `.env.json` at the project root contains the remote Supabase URL and anon key per project memory `project_dart_defines.md`. Every Flutter run/build command below assumes `--dart-define-from-file=.env.json` is passed.

4. **Branch state clean**: on `007-super-admin-roles` branch; no uncommitted local Supabase changes that would diverge from the migrations.

---

## Step 1 — Apply the five Phase 7 migrations

Apply via Supabase MCP `apply_migration` in order. The migrations are idempotent; re-application is safe.

```text
1. apply_migration name="20260516120001_create_phase7_audit_triggers" body=<contents of supabase/migrations/20260516120001_create_phase7_audit_triggers.sql>
2. apply_migration name="20260516120002_create_phase7_write_policies" body=<contents of supabase/migrations/20260516120002_create_phase7_write_policies.sql>
3. apply_migration name="20260516120003_create_mutate_role_rpc" body=<contents of supabase/migrations/20260516120003_create_mutate_role_rpc.sql>
4. apply_migration name="20260516120004_create_user_role_assignment_rpcs" body=<contents of supabase/migrations/20260516120004_create_user_role_assignment_rpcs.sql>
5. apply_migration name="20260516120005_phase7_advisor_hardening" body=<contents of supabase/migrations/20260516120005_phase7_advisor_hardening.sql>
```

**Verification (SC-018)**:

```sql
SELECT name FROM supabase_migrations.schema_migrations WHERE name LIKE '20260516%' ORDER BY name;
-- Expected: all 5 migrations listed.
```

**Idempotency check**: Re-apply each migration. Confirm no errors and no duplicate triggers:

```sql
SELECT tgname, count(*) FROM pg_trigger GROUP BY tgname HAVING count(*) > 1;
-- Expected: 0 rows.
```

**Advisor check** (run after migration 5):

```text
Supabase MCP get_advisors type=security
```

Expected: no new advisor findings introduced by Phase 7 (the advisor-hardening migration neutralizes the SECURITY DEFINER PUBLIC-execute warnings that would otherwise appear).

---

## Step 2 — Bootstrap the first super_admin (Phase 7 entry condition)

Per R-03, Phase 6 deliberately left zero `super_admin` `user_roles` rows. Phase 7's UI is useful only once at least one super_admin exists.

Pick the project owner's `auth.users.id` (or another trusted UUID). Run via Supabase MCP `execute_sql` as `postgres`:

```sql
INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
SELECT '<chosen-uuid>', id, NULL, now()
FROM public.roles WHERE key = 'super_admin';
```

**Verification**:

```sql
SELECT count(*) FROM public.user_roles ur
JOIN public.roles r ON r.id = ur.role_id
WHERE r.key = 'super_admin';
-- Expected: 1 (or more, if additional super_admins were bootstrapped).

SELECT action, actor_user_id, target_id FROM public.audit_logs
WHERE action = 'user_role.granted' AND target_id = '<chosen-uuid>'
ORDER BY created_at DESC LIMIT 1;
-- Expected: action='user_role.granted', actor_user_id IS NULL (postgres session), target_id = <chosen-uuid>.
```

The audit row from the Phase 6 `trg_user_roles_audit_granted` trigger confirms the bootstrap fired through the audit pipeline.

---

## Step 3 — Build and install the Phase 7 app

From the project root:

```powershell
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs   # regenerate injection.config.dart for new BLoCs/use cases/repositories
flutter build apk --release --dart-define-from-file=.env.json
```

Install the APK on the reference Infinix Note 8 device:

```powershell
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

---

## Step 4 — US1: Super-admin entry tile + route guard (SC-001, SC-002)

### 4a. Regular `user`-only account

1. Sign in on the device as a regular `user`-only account.
2. **Expected**: home page admin tile is HIDDEN.
3. Hand-type `/admin/super-admin/roles` into a deep-link entry (`adb shell am start -W -a android.intent.action.VIEW -d "alnujom://admin/super-admin/roles" com.alnujom.app` or via the app's URL handler).
4. **Expected**: route guard refuses the navigation; the user lands on home or `/admin` (whichever Phase 6's guard prescribes for unauthorized admin routes).

### 4b. Phase-6 admin

1. Sign out, sign in as a user with only the `admin` role (post-Phase-6 backfill admin).
2. **Expected**: home page admin tile VISIBLE; `/admin` opens; admin home shows the Phase 5 "Account approvals" tile.
3. **Expected**: NO "Super-admin" tile on the admin home (admin lacks the super-admin-category keys).
4. Hand-type `/admin/super-admin/roles` deep-link.
5. **Expected**: bounced to `/admin` (Phase 6 admin home).

### 4c. The bootstrapped super_admin

1. Sign out, sign in as the user from Step 2 (now holding `super_admin`).
2. **Expected**: home page admin tile VISIBLE; `/admin` opens; admin home shows TWO tiles: "Account approvals" and "Super-admin".
3. Tap "Super-admin".
4. **Expected**: `RolesListPage` opens.

### 4d. Defense-in-depth: server-side rejects for non-super_admin

Via Supabase MCP `execute_sql` simulating a non-super_admin JWT:

```sql
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<regular-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;

-- 4d-i. RPC call rejected
SELECT public.mutate_role(op := 'create', role_id := NULL, role_key := 'test', display_name := '{"ar":"اختبار","en":"Test"}'::jsonb, description := NULL, permission_keys := ARRAY[]::TEXT[], expected_updated_at := NULL);
-- Expected: ERROR 42501 'permission denied: roles.create'.

-- 4d-ii. Direct INSERT rejected by RLS
INSERT INTO public.roles (key, display_name, is_system) VALUES ('test_blocked', '{"ar":"اختبار","en":"Test"}', false);
-- Expected: ERROR 42501 (the roles_phase7_insert RLS policy rejects).

RESET ROLE;
```

**SC-012 + SC-013 satisfied.**

---

## Step 5 — US2: RolesListPage with system-row badging (SC-003)

1. As the super_admin, open `RolesListPage`.
2. **Expected**: exactly 7 rows (the seeded system roles); each row carries an `is_system` badge.
3. **Expected**: row order is alphabetical by `roles.key` (`admin`, `agency_admin`, `agent`, `moderator`, `owner`, `super_admin`, `user`).
4. **Expected**: each row shows its localized `display_name` in the active locale (Arabic by default).
5. Toggle device locale to English. Confirm names flip.
6. Long-press any system row.
7. **Expected**: no "Delete" or "Rename" affordance appears.

---

## Step 6 — US3: Role editor (SC-004, SC-024, SC-025)

### 6a. Standard role permission edit

1. Tap the `admin` row → `RoleEditorPage` opens.
2. **Expected**: 17 permissions checked (the §9.1 admin mapping); `display_name` inputs pre-filled with `ar`+`en` values from seed; `description` empty.
3. Uncheck `ads.manage`.
4. Tap Save.
5. **Expected**: editor pops to `RolesListPage`; admin row's permission count shows 16.
6. Verify via Supabase MCP `execute_sql`:
   ```sql
   SELECT count(*) FROM public.role_permissions rp JOIN public.roles r ON r.id = rp.role_id WHERE r.key = 'admin';
   -- Expected: 16.

   SELECT action FROM public.audit_logs WHERE created_at > now() - interval '1 minute' ORDER BY created_at;
   -- Expected: role.updated, role_permission.revoked.
   ```
7. Re-open `admin` editor; re-check `ads.manage`; Save.
8. Verify count returns to 17. Audit log shows another `role.updated` + `role_permission.granted`.

### 6b. super_admin permission-set immutability (SC-025, SC-026)

1. Tap the `super_admin` row → `RoleEditorPage` opens.
2. **Expected**: permission checklist rendered READ-ONLY (all checkboxes disabled); a localized banner above the checklist reads "The super_admin role's permission set cannot be changed."
3. **Expected**: `display_name` and `description` fields ARE editable.
4. Edit `display_name.en` to "Super Administrator". Tap Save.
5. **Expected**: save succeeds; `RolesListPage` shows "Super Administrator" for the super_admin row in English locale.
6. Force a server-side rejection via Supabase MCP `execute_sql` (simulating a crafted client):
   ```sql
   DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<super_admin-uuid>","role":"authenticated"}', true); END $$;
   SET LOCAL ROLE authenticated;
   SELECT public.mutate_role(
     op := 'update',
     role_id := (SELECT id FROM public.roles WHERE key = 'super_admin'),
     role_key := NULL, display_name := NULL, description := NULL,
     permission_keys := ARRAY['currencies.manage'],
     expected_updated_at := (SELECT updated_at FROM public.roles WHERE key = 'super_admin')
   );
   -- Expected: ERROR 42501 'super_admin permission set is immutable'.
   ```

### 6c. Optimistic-lock conflict (SC-024)

1. Open the `admin` editor on the device.
2. Without saving, run via Supabase MCP `execute_sql` (simulating another super_admin):
   ```sql
   DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<super_admin-uuid>","role":"authenticated"}', true); END $$;
   SET LOCAL ROLE authenticated;
   SELECT public.mutate_role(
     op := 'update',
     role_id := (SELECT id FROM public.roles WHERE key = 'admin'),
     role_key := NULL,
     display_name := NULL,
     description := 'changed by other session',
     permission_keys := NULL,
     expected_updated_at := (SELECT updated_at FROM public.roles WHERE key = 'admin')
   );
   ```
3. On the device, attempt to Save the original edit.
4. **Expected**: localized error "this role was changed by another super_admin — reload and re-apply your edits"; a "Reload" affordance is visible.
5. Tap "Reload"; confirm the editor refreshes with the new description and the new `updated_at` token.

Force a stale-token rejection programmatically:

```sql
SELECT public.mutate_role(
  op := 'update',
  role_id := (SELECT id FROM public.roles WHERE key = 'admin'),
  role_key := NULL, display_name := NULL, description := 'try with stale',
  permission_keys := NULL,
  expected_updated_at := '1970-01-01'::timestamptz
);
-- Expected: ERROR 40001 (serialization_failure) 'role concurrent edit'.
```

---

## Step 7 — US4: Custom role lifecycle (SC-005, SC-006, SC-007)

### 7a. Create

1. From `RolesListPage`, tap "Create".
2. Fill: `roleKey = finance`; `display_name.ar = محاسبة`; `display_name.en = Finance`; description empty; check `currencies.manage` only.
3. Tap Save.
4. **Expected**: list shows 8 rows now; the `finance` row is at the alphabetically-correct position; no `is_system` badge.
5. Verify:
   ```sql
   SELECT key, is_system FROM public.roles WHERE key = 'finance';
   -- Expected: ('finance', false).

   SELECT p.key FROM public.role_permissions rp
   JOIN public.roles r ON r.id = rp.role_id
   JOIN public.permissions p ON p.id = rp.permission_id
   WHERE r.key = 'finance';
   -- Expected: ('currencies.manage').

   SELECT action FROM public.audit_logs WHERE created_at > now() - interval '1 minute' ORDER BY created_at;
   -- Expected: role.created, role_permission.granted.
   ```

### 7b. Duplicate-key rejection

1. From `RolesListPage`, tap "Create".
2. Try `roleKey = admin`. **Expected**: localized "this key is already used" error; form refuses to save.
3. Try `roleKey = super_admin`. **Expected**: same error (the RPC raises `23505` defensively).

### 7c. Delete with no users

1. From `RolesListPage`, long-press the `finance` row → "Delete".
2. Confirmation dialog appears; states "0 users currently affected".
3. Confirm.
4. **Expected**: row disappears from the list.
5. Verify:
   ```sql
   SELECT count(*) FROM public.roles WHERE key = 'finance';
   -- Expected: 0.

   SELECT action FROM public.audit_logs WHERE created_at > now() - interval '1 minute' ORDER BY created_at;
   -- Expected: role.deleted, role_permission.revoked (cascaded).
   ```

### 7d. Delete with users (SC-007)

1. Re-create the `finance` role per 7a.
2. Via Supabase MCP `execute_sql`, grant the role to a test user:
   ```sql
   INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
   SELECT '<test-user-uuid>', id, NULL, now() FROM public.roles WHERE key = 'finance';
   ```
3. From `RolesListPage`, long-press `finance` → "Delete".
4. **Expected**: confirmation dialog states "1 user currently affected" and offers "Revoke and delete" + "Cancel".
5. Tap "Revoke and delete".
6. **Expected**: N `user_role.revoked` audit rows + 1 `role.deleted` row + cascaded `role_permission.revoked` row(s).

---

## Step 8 — US5: User-role assign / revoke (SC-008, SC-009, SC-010, SC-011)

### 8a. Search

1. From admin home, tap "Super-admin", then "Assign roles" (or navigate to `/admin/super-admin/assign`).
2. Type a known user's phone prefix in the search field.
3. **Expected**: results appear within ~1 second (debounced 300ms); each result shows `display_name` (full_name or username), phone, current roles.

### 8b. Grant a non-super_admin role

1. Tap a result.
2. Drawer opens with the user's current roles.
3. Tap "Grant role" → role picker.
4. **Expected**: every role from `RolesListPage` is listed EXCEPT the ones the user already holds.
5. Pick `moderator`.
6. **Expected**: standard `ConfirmationDialog`.
7. Confirm.
8. **Expected**: drawer refreshes to include `moderator`.
9. Verify:
   ```sql
   SELECT key FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id WHERE ur.user_id = '<target-uuid>' ORDER BY key;
   -- Expected: moderator, user (the always-implicit user role from Phase 6 + the new moderator).

   SELECT action, actor_user_id, target_id FROM public.audit_logs WHERE action = 'user_role.granted' AND target_id = '<target-uuid>' ORDER BY created_at DESC LIMIT 1;
   -- Expected: actor_user_id = <super_admin-uuid>, target_id = <target-uuid>.
   ```

### 8c. Grant the super_admin role with two-step confirmation (SC-009)

1. Search and select a different user.
2. Tap "Grant role" → pick `super_admin`.
3. **Expected**: `SuperAdminGrantConfirmationDialog` opens (NOT the standard dialog).
4. Acknowledge the consequences (button A).
5. Type a wrong value in the typed-match field.
6. **Expected**: "Confirm grant" button remains disabled.
7. Type the target user's correct phone (E.164).
8. **Expected**: button enables. Tap.
9. **Expected**: grant succeeds; drawer refreshes to include `super_admin`.
10. Verify the audit row carries `target_id = <target-uuid>` and the new user holds the super_admin role.

### 8d. Block super_admin self-revoke (SC-010, R-05)

1. Search for the bootstrapped super_admin's own profile.
2. Tap the result → drawer opens.
3. Locate the `super_admin` row in the user's current roles.
4. **Expected**: NO remove (revoke) affordance on this row.
5. Force a server-side rejection via Supabase MCP `execute_sql` (simulating the super_admin):
   ```sql
   DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<super_admin-uuid>","role":"authenticated"}', true); END $$;
   SET LOCAL ROLE authenticated;
   SELECT public.revoke_role_from_user(
     target_user_id := '<super_admin-uuid>',
     target_role_id := (SELECT id FROM public.roles WHERE key = 'super_admin')
   );
   -- Expected: ERROR 42501 'super_admin self-revoke forbidden'.
   RESET ROLE;
   ```

### 8e. Mid-session propagation (SC-011 — two-device test)

1. On a SECOND device, sign in as the user granted `moderator` in step 8b.
2. Confirm the user does NOT have the admin tile visible.
3. Background the app on the second device (press Home — DO NOT force-quit).
4. On the FIRST device (super_admin's), navigate to `AssignRolePage`, search for the second device's user, GRANT them `admin` (or another role that imparts admin-category permissions).
5. Foreground the app on the second device.
6. **Expected**: within a few seconds, the admin tile APPEARS on the second device's home page. The Phase 6 lifecycle-resume `PermissionChecker.refresh()` fires and the navigation rebuilds.

### 8f. Revoke (SC-010)

1. On the first device, revoke the `admin` role from the second device's user.
2. On the second device, background → foreground.
3. **Expected**: the admin tile disappears within a few seconds.

---

## Step 9 — US6: Audit-trigger coverage (SC-014, SC-015, SC-016, SC-017)

### 9a. Confirm Phase 6 triggers still fire (SC-014)

```sql
SELECT tgname FROM pg_trigger WHERE tgrelid = 'public.user_roles'::regclass AND NOT tgisinternal ORDER BY tgname;
-- Expected: trg_user_roles_audit_granted, trg_user_roles_audit_revoked (the Phase 6 triggers still present).
```

### 9b. Confirm Phase 7 audit triggers on all three tables

```sql
SELECT relname, count(*) AS n_triggers FROM pg_trigger
JOIN pg_class ON pg_class.oid = pg_trigger.tgrelid
WHERE relname IN ('roles', 'role_permissions', 'permissions') AND NOT tgisinternal
GROUP BY relname;
-- Expected: roles=5 (3 audit + 1 set_updated_at + 1 enforce_role_system_immutability), role_permissions=2, permissions=3.
```

### 9c. Synthetic mutation produces audit rows (SC-015, SC-016)

Via Supabase MCP `execute_sql` (as super_admin):

```sql
SELECT public.mutate_role(op := 'create', role_id := NULL, role_key := 'audit_test',
  display_name := '{"ar":"اختبار","en":"AuditTest"}'::jsonb,
  description := NULL, permission_keys := ARRAY['users.view', 'reports.manage'],
  expected_updated_at := NULL);

SELECT action, count(*) FROM public.audit_logs
WHERE created_at > now() - interval '30 seconds'
GROUP BY action;
-- Expected: role.created=1, role_permission.granted=2.

-- Cleanup
SELECT public.mutate_role(op := 'delete',
  role_id := (SELECT id FROM public.roles WHERE key = 'audit_test'),
  role_key := NULL, display_name := NULL, description := NULL, permission_keys := NULL,
  expected_updated_at := (SELECT updated_at FROM public.roles WHERE key = 'audit_test'));

SELECT action, count(*) FROM public.audit_logs
WHERE created_at > now() - interval '10 seconds'
GROUP BY action;
-- Expected: role.deleted=1, role_permission.revoked=2 (cascade fired).
```

### 9d. System-row immutability (SC-017)

```sql
DELETE FROM public.roles WHERE key = 'admin';
-- Expected: ERROR 42501 'cannot delete system role: admin' (the Phase 6 enforce_role_system_immutability trigger fires).

UPDATE public.roles SET key = 'admin_renamed' WHERE key = 'admin';
-- Expected: ERROR 42501 'cannot rename system role: admin'.
```

---

## Step 10 — Constitution gates re-check

### 10a. SC-019 — Domain layer Supabase-free

```bash
grep -rn "package:supabase_flutter" lib/features/super_admin/domain/ lib/core/security/
# Expected: zero matches.
```

### 10b. SC-020 — No hardcoded role checks

```bash
grep -rnE "user\.role *== *['\"](super_admin|admin|moderator|user|owner|agent|agency_admin)['\"]" lib/features/super_admin/ lib/core/security/
# Expected: zero matches.

grep -rn "PermissionChecker.has\|PermissionChecker.any\|PermissionChecker.all" lib/features/super_admin/ | wc -l
# Expected: > 0 (every gate consults the checker).
```

### 10c. SC-021 — Localization coverage

```bash
# All 12 category keys present in both ARB files
grep -c "permissionCategory" lib/l10n/app_ar.arb
grep -c "permissionCategory" lib/l10n/app_en.arb
# Expected: 12 each.

# No literal Arabic or English strings in feature widgets
grep -rE 'Text\(["\047]' lib/features/super_admin/presentation/
# Expected: zero matches (every Text() takes l10n.someKey, not a literal).
```

### 10d. SC-022 — Theme tokens only

Visual inspection during the device walks above; reviewer cross-checks with `grep -rE '0x[fF][fF][0-9a-fA-F]{6}' lib/features/super_admin/`.

---

## Step 11 — Full golden-path walk (SC-023)

End-to-end on the reference device:

1. Sign in as the bootstrapped super_admin.
2. Open admin home → tap "Super-admin" → `RolesListPage` opens.
3. Tap the `admin` row → `RoleEditorPage` opens with 17 checked permissions.
4. Uncheck `ads.manage` → tap Save → confirm `RolesListPage` updates to show 16 permissions.
5. From admin home, tap "Account approvals" (Phase 5 surface) → confirm it still works (Phase 6 invariant preserved).
6. Back to admin home → tap "Super-admin" → tap "Assign roles".
7. Search for a known user → tap result → grant `moderator`.
8. Sign out. Sign in as that user on a second device. Confirm admin tile appears within seconds of foreground.
9. Verify the audit-log trail end-to-end:
   ```sql
   SELECT action, actor_user_id IS NOT NULL AS has_actor, target_id, created_at
   FROM public.audit_logs
   WHERE created_at > now() - interval '15 minutes'
   ORDER BY created_at;
   -- Expected: role.updated (step 4), role_permission.revoked (step 4), user_role.granted (step 7).
   ```

If all 11 steps pass, Phase 7 is shipped.

---

## Cleanup

After the walk:

1. Re-check `ads.manage` on the `admin` role via the editor (restore parity with the §9.1 default).
2. Optionally revoke the test `moderator` assignment from the second-device user.
3. Confirm no test rows remain in `public.roles` (`SELECT key FROM public.roles WHERE NOT is_system;` should be empty after cleanup of any custom roles).

---

## Step 12 — DEFERRED.md review (before squash-merge)

Per project memory `project_deferred_work.md`, before squash-merge:

1. Open `specs/007-super-admin-roles/DEFERRED.md`.
2. Confirm any intentional gaps are documented or that the file says "No deferrals — Phase 7 ships complete." (matching the Phase 6 pattern).

Known deferrals:

- Edge Function `mutate_role` path (R-06) — deferred until a phase needs Edge Function infrastructure for non-database reasons.
- Realtime cache refresh on `user_roles` (Phase 22 — project memory `project_phase22_perm_cache_revisit.md`).
- Bulk operations on `AssignRolePage` (R-20) — explicitly out of scope in v1.
- Lint guard extension for hardcoded role checks (Phase 6 R-21) — optional, carried forward as optional.

If any of these are explicitly re-scoped at implement time (e.g., "we decided to add the lint guard"), update `DEFERRED.md` to reflect the change.

---

## Cross-reference: every FR / SC mapped to a step

| Requirement | Verified by |
|---|---|
| FR-001 (audit triggers on roles) | Step 1 (apply), Step 9c (synthetic mutation) |
| FR-002 (audit triggers on role_permissions) | Step 1, Step 9c |
| FR-003 (audit triggers on permissions, defensive) | Step 1 (presence check); not exercised by user-facing flow (catalog is closed in v1) |
| FR-004 (write RLS on roles) | Step 4d (RLS rejection), Step 7a (RLS admit) |
| FR-005 (write RLS on role_permissions) | Step 6a (admit during edit), Step 4d (reject for non-super_admin) |
| FR-006 (write RLS on user_roles) | Step 8b (admit), Step 4d (defense-in-depth) |
| FR-007 (Phase 6 read posture preserved) | Step 1 (no Phase 6 policy edits) |
| FR-008 (mutate_role RPC) | Steps 6a, 6b, 6c, 7a, 7b, 7c, 7d, 9c |
| FR-009 (assign/revoke RPCs + super_admin two-step + self-revoke block) | Steps 8b, 8c, 8d |
| FR-010 (super_admin feature folder + pages) | Steps 5, 6, 7, 8 |
| FR-011 (tile visibility) | Steps 4a, 4b, 4c |
| FR-012 (superAdminCategoryKeys constant) | Step 10b (grep) + Step 4 (observed behavior) |
| FR-013 (route guards) | Step 4 (deep-link tests) |
| FR-014 (checked-in migration files) | Step 1 (apply via Supabase MCP) |
| FR-015 (supabase/docs updates) | Reviewer inspection at PR review |
| FR-016 (no hardcoded role checks) | Step 10b |
| FR-017 (current_user_is_admin body unchanged) | Reviewer inspection of diff |
| FR-018 (confirmation dialogs + two-step + self-revoke UI) | Steps 7c, 7d, 8c, 8d |
| FR-019 (quickstart documents bootstrap) | This file, Step 2 |
| FR-020 (Phase 6 triggers untouched) | Step 9a |
| FR-021 (PermissionChecker propagation unchanged) | Step 8e |
| SC-001 | Steps 4a, 4b, 4c |
| SC-002 | Step 4 deep-link tests |
| SC-003 | Step 5 |
| SC-004 | Step 6a |
| SC-005 | Step 7a |
| SC-006 | Step 7c |
| SC-007 | Step 7d |
| SC-008 | Step 8a |
| SC-009 | Steps 8b, 8c |
| SC-010 | Steps 8d, 8f |
| SC-011 | Step 8e |
| SC-012 | Step 4d |
| SC-013 | Step 4d |
| SC-014 | Step 9a |
| SC-015 | Step 9c |
| SC-016 | Step 9c |
| SC-017 | Step 9d |
| SC-018 | Step 1 |
| SC-019 | Step 10a |
| SC-020 | Step 10b |
| SC-021 | Step 10c |
| SC-022 | Step 10d |
| SC-023 | Step 11 |
| SC-024 | Step 6c |
| SC-025 | Step 6b |
| SC-026 | Step 6b |
| SC-027 | Step 10c |
