# Contract: `current_user_is_admin()` — Phase 5 Body Swap

**Owner**: Phase 5 (`supabase/migrations/20260510120003_swap_admin_predicate.sql`). The function itself is owned through its lifecycle by whichever phase last edited the body.
**Consumers**: every RLS policy and every SECURITY DEFINER helper that gates admin-only behavior (Phase 4: `profiles_admin_*` policies, `audit_logs_admin_read`; Phase 5: `account_approval_requests_admin_*` policies, the four admin-gated PII helpers, the approve/reject account-approval RPCs).
**Stability**: **The function signature is stable across the entire v1 lifecycle.** Only the body changes per phase. Phase 5's body swap matches the contract Phase 4 declared (`contracts/admin-predicate.md`) — Phase 5 is the first phase to actually flip the placeholder.

---

## Purpose

A single, swappable predicate that every admin-gated policy and every admin-gated SECURITY DEFINER helper calls. Centralizing the predicate behind one function realizes the spec's binding constraint: replacing the placeholder MUST NOT require touching every policy file.

## Function

```
current_user_is_admin() RETURNS BOOLEAN
```

- **Language**: SQL (Phase 5 body is a single SELECT; no PL/pgSQL needed).
- **Security**: `SECURITY INVOKER` (Phase 5 preserves Phase 4's choice — see `contracts/admin-predicate.md` R-05 rationale).
- **Volatility**: `STABLE` (same input session ⇒ same output within a statement).

## Phase 5 body

```sql
CREATE OR REPLACE FUNCTION current_user_is_admin() RETURNS BOOLEAN
LANGUAGE SQL STABLE AS $$
  SELECT COALESCE((SELECT is_admin FROM profiles WHERE user_id = auth.uid()), FALSE);
$$;
```

## Behavior change vs. Phase 4

| Caller scenario | Phase 4 result | Phase 5 result |
|---|---|---|
| Anonymous (no JWT) — `auth.uid()` returns NULL | `FALSE` (placeholder body returned FALSE for everyone) | `FALSE` (the inner SELECT yields no rows; `COALESCE(…, FALSE)` returns FALSE) |
| Authenticated user with `profiles.is_admin = false` | `FALSE` | `FALSE` |
| Authenticated user with `profiles.is_admin = true` | `FALSE` (placeholder) | `TRUE` |
| Authenticated user with no `profiles` row (impossible in normal operation — Phase 4's auto-provision trigger guarantees one) | `FALSE` | `FALSE` (defense-in-depth via `COALESCE`) |

## Effects on existing Phase 4 policies (no policy file edited)

| Policy (file) | Phase 4 effect | Phase 5 effect |
|---|---|---|
| `profiles_admin_read` (`profiles_policies.sql`) | Always blocked (placeholder = FALSE) | Admin can read every profile |
| `profiles_admin_write_status` (`profiles_policies.sql`) | Always blocked | Admin can write `account_status` / `publisher_status` |
| `audit_logs_admin_read` (`audit_logs_policies.sql`) | Always blocked | Admin can read `audit_logs` |
| `account_approval_requests_admin_read` (Phase 5) | (n/a — table did not exist) | Admin can read every request row |
| `account_approval_requests_admin_update` (Phase 5) | (n/a) | Admin can transition request rows |

## Invariants

- **Single point of swap**: Phase 5's migration `20260510120003_swap_admin_predicate.sql` contains exactly one `CREATE OR REPLACE FUNCTION` statement and a header comment. No other file in the Phase 5 PR edits any Phase 4 policy.
- **No `SECURITY DEFINER`**: Phase 5 preserves the `SECURITY INVOKER` default. The helper reads `profiles.is_admin` for `auth.uid()`, which RLS on `profiles` already permits the user to read for themselves. SECURITY DEFINER would change the `auth.uid()` resolution context unnecessarily.
- **`COALESCE(…, FALSE)`**: defends against the impossible-but-cheap-to-handle case where a user has no `profiles` row.
- **Deterministic with respect to session**: `STABLE` volatility means a single statement cannot see the user flip mid-query. A new statement (e.g., the next policy evaluation in the next request) re-reads the row.

## Phase 6 swap (forward reference)

Phase 6's spec (`specs/006-roles-permissions/`) ships the role/permission system. Its migration will:
1. Backfill existing `profiles.is_admin = true` users into the `admin` role via `user_roles`.
2. Drop `profiles.is_admin` (no longer needed).
3. `CREATE OR REPLACE FUNCTION current_user_is_admin()` body to call `current_user_has_permission('users.view')` (or whatever anchor permission Phase 6's spec settles on).

The signature, security context, and volatility stay the same; the call sites (Phase 4 policies + Phase 5 policies + Phase 5 helpers) are not edited.

## Verification

After applying `20260510120003_swap_admin_predicate.sql`:

```sql
-- 1. Confirm the body has been swapped.
SELECT prosrc FROM pg_proc WHERE proname = 'current_user_is_admin';
-- Expected: includes 'SELECT COALESCE((SELECT is_admin FROM profiles WHERE user_id = auth.uid()), FALSE);'

-- 2. Simulate a non-admin authenticated session.
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<non-admin-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT current_user_is_admin();  -- Expected: FALSE
RESET ROLE;

-- 3. Simulate an admin authenticated session (after step 2's bootstrap admin).
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<admin-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT current_user_is_admin();  -- Expected: TRUE
RESET ROLE;
```

(Per `quickstart.md`'s pattern of wrapping multi-statement RLS verifications in a single `execute_sql` call to preserve the JWT-claims context across statements.)
