# Contract: `current_user_has_permission(perm_key TEXT) RETURNS BOOLEAN`

**Owner**: Phase 6 (`supabase/migrations/20260515120005_create_permission_predicate.sql`; hardened in `20260515120008_phase6_advisor_hardening.sql`).
**Consumers**: every RLS policy authored from Phase 6 onward that gates a specific capability; the new `profiles_phase6_users_view` policy (Phase 6); the `user_roles_admin_cross_read` policy (Phase 6); every future per-feature admin policy (Phase 8 locations, Phase 9 currencies, Phase 12 listings approval, Phase 18 reports, Phase 19 agencies, Phase 21 ads, Phase 23 settings).
**Stability**: Signature, return type, security context, volatility, and `search_path` are stable across the entire v1 lifecycle. Body MAY evolve if a future spec changes the role-permission resolution shape (no such change is planned).

---

## Purpose

The central permission-keyed gate. Every RLS policy that says "this action requires capability X" calls `current_user_has_permission('X')` in its USING / WITH CHECK clause. The function returns `TRUE` iff the signed-in user holds any role whose mappings include the requested permission key.

## Function

```sql
CREATE OR REPLACE FUNCTION public.current_user_has_permission(perm_key TEXT)
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
      JOIN public.role_permissions rp ON rp.role_id = ur.role_id
      JOIN public.permissions p ON p.id = rp.permission_id
      WHERE ur.user_id = auth.uid()
        AND p.key = perm_key
    )
  ), FALSE);
$$;

REVOKE EXECUTE ON FUNCTION public.current_user_has_permission(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_has_permission(TEXT) TO authenticated;
```

## Semantics

| Caller scenario | Result |
|---|---|
| Anonymous (no JWT) — `auth.uid()` returns NULL | `FALSE` (the EXISTS subquery joins on a NULL user_id, yields no rows; COALESCE returns FALSE) |
| Authenticated user with no `user_roles` rows | `FALSE` |
| Authenticated user holding a role that maps to the requested key | `TRUE` |
| Authenticated user holding a role that does NOT map to the requested key | `FALSE` |
| `perm_key` is a string not in the seeded `permissions.key` set | `FALSE` (no error — the EXISTS yields no rows) |

## Invariants

- **No raise**: the function never raises. Bad inputs (unknown key, no `auth.uid()`) return `FALSE`.
- **`STABLE` volatility**: a single statement sees a consistent answer; a new statement (or transaction) re-evaluates against fresh `user_roles` / `role_permissions` reads.
- **`SECURITY DEFINER` with explicit `search_path`**: prevents schema-injection attacks. Matches the Phase 5 R-12 / advisor-hardening pattern.
- **`REVOKE … FROM PUBLIC, anon`**: unauthenticated callers cannot probe permission membership. This is defense-in-depth — the function would already return FALSE for them, but the REVOKE prevents the function from being called at all from non-authenticated contexts.
- **`GRANT EXECUTE TO authenticated`**: every signed-in session can call the function (it must be callable from RLS policy USING clauses, which evaluate in the caller's session role).

## Verification (Supabase MCP `execute_sql`)

```sql
-- 1. From a privileged session, confirm function exists and definition is right
SELECT pg_get_functiondef('public.current_user_has_permission(TEXT)'::regprocedure);

-- 2. Simulate an admin session and check users.approve
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<admin-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT current_user_has_permission('users.approve');  -- Expected: TRUE
SELECT current_user_has_permission('settings.manage');  -- Expected: FALSE (super_admin only)
SELECT current_user_has_permission('not_a_real_key');  -- Expected: FALSE
RESET ROLE;

-- 3. Simulate a moderator and check users.view vs users.approve
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<moderator-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT current_user_has_permission('users.view');    -- Expected: TRUE
SELECT current_user_has_permission('users.approve'); -- Expected: FALSE
RESET ROLE;
```

## Forward references

- Every future admin-feature spec (Phase 8+) authors its RLS policies in terms of this function. The function signature is the stable contract — feature specs never invent their own permission-resolution mechanism.
- If a future spec introduces hierarchical permissions (a permission key implying another), the body MAY be extended with a recursive lookup; the signature stays unchanged.
