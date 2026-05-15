# Phase 6 — Roles & Permissions: Handoff Notes

**Branch**: `006-roles-permissions`  
**Date completed**: 2026-05-15  
**Spec**: `specs/006-roles-permissions/spec.md`

---

## Supabase Advisor State (T062)

Run after all 8 Phase 6 migrations applied + advisor hardening (`20260515120008`).

### Pre-existing warnings (Phase 4 / 5 baseline — NOT introduced by Phase 6)

| Advisor key | Function | Notes |
|---|---|---|
| `function_search_path_mutable` | `set_updated_at` | Phase 4 utility trigger; hardening deferred to a future spec |
| `anon_security_definer_function_executable` | `handle_new_auth_user` | Phase 4 auth trigger; callable by anon intentionally (fires on signup) |
| `authenticated_security_definer_function_executable` | `app_vault_secret_for_self` | Phase 5 PII helper; intentionally callable by authenticated users |
| `authenticated_security_definer_function_executable` | `app_vault_secret_for_user` | Phase 5 PII helper; intentionally callable by authenticated (admin-gated internally) |
| `authenticated_security_definer_function_executable` | `app_vault_set_private_contact_methods_for_self` | Phase 5 PII helper; intentionally callable |
| `authenticated_security_definer_function_executable` | `app_vault_set_secret_for_self` | Phase 5 PII helper; intentionally callable |
| `authenticated_security_definer_function_executable` | `app_vault_set_secret_for_user` | Phase 5 PII helper; intentionally callable (admin-gated internally) |
| `authenticated_security_definer_function_executable` | `approve_account_approval_request` | Phase 5 admin RPC; intentionally callable (admin check inside function) |
| `authenticated_security_definer_function_executable` | `reject_account_approval_request` | Phase 5 admin RPC; intentionally callable (admin check inside function) |
| `authenticated_security_definer_function_executable` | `handle_new_auth_user` | Phase 4 trigger; Supabase flags it but it is trigger-only by convention |
| `auth_leaked_password_protection` | Auth config | Project setting; enable in Supabase dashboard when ready for production |

### Phase 6 functions — expected advisor warnings

| Advisor key | Function | Status |
|---|---|---|
| `authenticated_security_definer_function_executable` | `current_user_has_permission(TEXT)` | **INTENTIONAL** — this is a user-callable helper invoked by RLS policies and directly by Flutter. `GRANT EXECUTE TO authenticated` is explicit in migration 8. |
| `authenticated_security_definer_function_executable` | `current_user_is_admin()` | **INTENTIONAL** — same as above. Used directly by all admin-gated policies. |
| `authenticated_security_definer_function_executable` | `auto_create_user_role_for_user()` | **KNOWN RESIDUAL** — migration 8 revokes from `PUBLIC, anon`; Supabase's default `authenticated` grant persists. This function is trigger-only (no useful effect if called directly without an active INSERT on profiles). The risk is negligible: calling it directly returns `NEW` but there is no `NEW` outside a trigger context — it raises `ERROR: record "new" is not assigned yet`. Accept for MVP; harden in Phase 7 advisor migration if needed. |

### Zero NEW warnings beyond baseline

All Phase 6 security advisor warnings fall into one of two categories:
1. **Intentional** (`current_user_has_permission`, `current_user_is_admin`) — correctly callable by authenticated users.
2. **Known residual** (`auto_create_user_role_for_user`) — trigger-only function; direct call is a no-op/error.

No Phase 6 migration introduced a new unintentional security regression.

---

## SC-017 Idempotency Check Results (T063)

All 8 Phase 6 migrations re-applied after initial deployment. Results:

| Migration | Re-apply result | Notes |
|---|---|---|
| `20260515120001_create_roles` | ✓ success | `CREATE TABLE IF NOT EXISTS` + `OR REPLACE` + `ON CONFLICT DO NOTHING` |
| `20260515120002_create_permissions` | ✓ success | Same pattern |
| `20260515120003_create_role_permissions` | ✓ success | Same pattern |
| `20260515120004_create_user_roles` | ✓ success | Same pattern |
| `20260515120005_create_permission_predicate` | ✓ success | `OR REPLACE` function + `DROP IF EXISTS` policy |
| `20260515120006_swap_admin_predicate_to_role_check` | ✓ success | `OR REPLACE` function + `DROP IF EXISTS` policy |
| `20260515120007_backfill_is_admin_and_drop` | ✗ fails on step 1 (`column p.is_admin does not exist`) | **Expected** — this is a one-time data migration. Step 1 references the `is_admin` column that step 3 drops. On re-apply, the column is already gone. Steps 3 and 4 would be idempotent (`DROP COLUMN IF EXISTS`, `OR REPLACE`), but the query planner rejects step 1 before reaching them. Acceptable: the backfill is a one-time operation; the migration name is tracked and will not be re-applied in a normal deploy flow. |
| `20260515120008_phase6_advisor_hardening` | ✓ success | `REVOKE/GRANT` operations are idempotent |

Row counts after re-apply (unchanged from initial deploy):
- `roles`: 7
- `permissions`: 24
- `role_permissions`: 46 (5 moderator + 17 admin + 24 super_admin)
- `user_roles`: 7 (real users + synthetic test users)
- `profiles.is_admin` column: absent (confirmed 0 rows in `information_schema.columns`)

---

## SC-013: RLS Blocks Non-Admin `user_roles` INSERT (T060a)

JWT-claims-simulated a regular user (`11111111-1111-1111-1111-111111111111`) and attempted:

```sql
INSERT INTO public.user_roles (user_id, role_id, ...) VALUES (auth.uid(), ..., NULL, now());
```

Result: `ERROR 42501: new row violates row-level security policy for table "user_roles"` ✓

No INSERT policy exists on `user_roles` in Phase 6. Phase 7 adds INSERT/DELETE policies
for super-admin-only role assignments.

---

## Super-Admin Bootstrap (T064 — operational)

User `6583a883-123c-4c62-a1ad-00e11b124c8b` (phone `+963991234567`) was assigned the
`super_admin` role via:

```sql
INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
VALUES ('6583a883-123c-4c62-a1ad-00e11b124c8b', (SELECT id FROM public.roles WHERE key = 'super_admin'), NULL, now())
ON CONFLICT (user_id, role_id) DO NOTHING;
```

This user also holds the `user` role (auto-provisioned at registration). The super_admin
role grants all 24 permissions, including `users.approve`, so the admin queue is accessible.

---

## Phase 22 Follow-Up

When Phase 22 ships push + Realtime notifications, the spec **must** revisit Phase 6's
three-point `PermissionChecker` cache refresh strategy and consider adding a Realtime
subscription on `user_roles`. The three current observation points are:

1. Auth-state listener (`AuthBloc._onSessionRefreshed`) — runs `load()` on sign-in, `clear()` on sign-out.
2. Foreground resume (`AuthBloc._onAppResumedRefresh`) — runs `refresh()`.
3. Manual trigger via `AuthBloc.add(AppResumedRefresh())` — available but not wired to any UI.

See project memory `project_phase22_perm_cache_revisit.md`.

---

## Manual Device Walkthrough Required (T066)

The final SC-018 check requires a cold-launch walkthrough on the Infinix Note 8:

1. Cold app launch (force-quit first).
2. Sign in as super_admin (`+963991234567`).
3. Main navigation shows admin tile → tap → admin home → "Account approvals" tile → queue loads.
4. Approve a pending registration → success.
5. Sign out → sign in as regular user → no admin tile → profile shows "User" role only.

**This step cannot be completed by the AI agent — it requires physical device interaction.**
The user must perform this walkthrough and report the result before squash-merging the PR.
