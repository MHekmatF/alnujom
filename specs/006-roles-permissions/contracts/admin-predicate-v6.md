# Contract: `current_user_is_admin()` — Phase 6 Body Swap

**Owner**: Phase 6 (`supabase/migrations/20260515120006_swap_admin_predicate_to_role_check.sql`). Each phase that swaps the body is the temporary owner; this contract supersedes the Phase 5 `admin-predicate-v5.md` body.
**Consumers**: every RLS policy and SECURITY DEFINER helper that gates "any admin-tier user" — Phase 4: `profiles_admin_*` policies, `audit_logs_admin_read`; Phase 5: `account_approval_requests_admin_*` policies, the four admin-gated Vault PII helpers, the approve/reject account-approval RPCs.
**Stability**: **The function signature, return type, security context, volatility, and `search_path` qualifier are stable across the entire v1 lifecycle.** Only the body changes per phase. Phase 6 is the LAST planned body swap — future phases that need finer-grained gating use `current_user_has_permission(<key>)` directly instead of `current_user_is_admin()`.

---

## Purpose

Preserves the Phase 4 / Phase 5 central-helper invariant: one function definition embodies the "is this caller an admin-tier user?" predicate, and every consuming policy / helper continues to work after the body swap. Phase 6 swaps the body from Phase 5's column-read to a role-membership check.

## Body (Phase 6)

```sql
CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT COALESCE((
    EXISTS (
      SELECT 1
      FROM public.user_roles ur
      JOIN public.roles r ON r.id = ur.role_id
      WHERE ur.user_id = auth.uid()
        AND r.key IN ('admin', 'super_admin')
    )
  ), FALSE);
$$;
```

## Behavior change vs. Phase 5

| Caller scenario | Phase 5 result | Phase 6 result |
|---|---|---|
| Anonymous (no JWT) — `auth.uid()` returns NULL | `FALSE` (COALESCE returns FALSE) | `FALSE` (EXISTS over empty join + COALESCE returns FALSE) |
| Authenticated user with `profiles.is_admin = false` (Phase 5) | `FALSE` | n/a — column no longer exists |
| Authenticated user holding only `user` role (Phase 6) | n/a | `FALSE` |
| Authenticated user with `profiles.is_admin = true` (Phase 5) → backfilled to `admin` role (Phase 6) | `TRUE` | `TRUE` |
| Authenticated user holding `moderator` role (Phase 6 only — could not exist in Phase 5) | n/a | `FALSE` (moderator is not admin-tier) |
| Authenticated user holding `super_admin` role | n/a (no super_admin in Phase 5) | `TRUE` |

**The set of users for whom this function returned `TRUE` at the end of Phase 5 is EXACTLY the set for whom it returns `TRUE` at the start of Phase 6** — because Phase 6's backfill converts every `is_admin=true` user into an `admin`-role assignment, and zero users hold `super_admin` immediately after Phase 6 deploy (R-16 — Option C). The two sets coincide; every Phase 5 admin remains an admin.

## Effects on existing Phase 4 / Phase 5 policies (NO POLICY FILE EDITED)

| Policy / function | Phase 4 / 5 effect | Phase 6 effect |
|---|---|---|
| `profiles_admin_read`, `profiles_admin_write_status` (Phase 4 policies) | Admin can read every profile / write statuses | Same — body swap continues to admit the same admin users |
| `audit_logs_admin_read` (Phase 4) | Admin can read `audit_logs` | Same |
| `account_approval_requests_admin_read`, `account_approval_requests_admin_update` (Phase 5) | Admin can read / mutate request rows | Same |
| `app_vault_secret_for_user(p_user_id, field_name)` (Phase 5 — admin-gated PII decrypt) | Admin decrypts other users' PII | Same — Q3 — Option A keeps the gate (moderators do NOT inherit PII decrypt) |
| `enforce_profile_status_admin_only()` trigger | Blocks non-admin client mutations of `account_status` / `publisher_status` | Same (the body is also rewritten in the same migration 7 to drop the dropped-column reference, but the admin gate continues to use `current_user_is_admin()`) |

## Invariants

- **Single body-swap migration**: `20260515120006_swap_admin_predicate_to_role_check.sql` contains exactly one `CREATE OR REPLACE FUNCTION` statement (plus a header comment). No other file in the Phase 6 PR edits any Phase 4 or Phase 5 policy.
- **`SECURITY DEFINER`** is preserved from Phase 5 R-12 (Phase 4's original placeholder was `SECURITY INVOKER`; Phase 5's hardening pass added `SECURITY DEFINER` with `SET search_path`).
- **`COALESCE(…, FALSE)`** defends against the empty-result case (e.g., user with no `user_roles` row — impossible after the FR-011 backfill, but defensive).

## Phase 7+ direction (forward reference)

Phase 6 is the LAST planned body swap. New policies introduced in Phase 7 (super-admin UI) and beyond use `current_user_has_permission(<specific key>)` directly. The `current_user_is_admin()` helper is retained as a "any admin-tier user" alias — convenient when a policy doesn't care which specific admin permission gates access (e.g., reading audit logs is gated by "user is an admin" rather than a specific audit-permission key, until/unless a future spec decides otherwise).

## Verification (Supabase MCP `execute_sql`)

```sql
-- 1. Confirm the body has been swapped to the role-membership check
SELECT pg_get_functiondef('public.current_user_is_admin()'::regprocedure);
-- Expected: includes 'EXISTS (SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id ...'

-- 2. Simulate a regular user
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<regular-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT current_user_is_admin();  -- Expected: FALSE
RESET ROLE;

-- 3. Simulate an admin (post-backfill)
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<admin-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT current_user_is_admin();  -- Expected: TRUE
RESET ROLE;

-- 4. Simulate a moderator
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<moderator-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT current_user_is_admin();  -- Expected: FALSE (moderator is not in the admin-tier set)
RESET ROLE;
```
