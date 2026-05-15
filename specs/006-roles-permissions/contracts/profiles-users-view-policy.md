# Contract: `profiles_phase6_users_view` Stacked Read Policy

**Owner**: Phase 6 (`supabase/policies/profiles_phase6_users_view.sql`).
**Consumers**: every authenticated session whose effective permission set includes `users.view` — moderators (5 permissions including this one), admins (16), super_admins (24). Phase 6 Flutter consumer: the rehosted Phase 5 admin queue (when it joins `account_approval_requests → profiles` to display registrant info, the read now succeeds for moderators because they hold `users.view`).
**Stability**: Policy name is stable for v1.

---

## Purpose

Adds a permission-keyed cross-user read path on `profiles` without editing Phase 4's `profiles_policies.sql`. Preserves Phase 4 R-05 / Phase 5 R-12 central-helper invariants by living in a separate policy file.

## SQL

```sql
DROP POLICY IF EXISTS profiles_phase6_users_view ON public.profiles;

CREATE POLICY profiles_phase6_users_view
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('users.view'));
```

## Effective grant after this policy lands

PostgreSQL ORs together the USING clauses of multiple SELECT policies on the same table for the same role. The Phase 4 `profiles_policies.sql` already defines `profiles_self_read` (`auth.uid() = user_id`). After Phase 6's stacked policy, the effective grant on `profiles` SELECT is:

```
(auth.uid() = user_id)             -- Phase 4 self-read
OR
(current_user_has_permission('users.view'))  -- Phase 6 cross-user read
```

Phase 4's admin-read policy (`profiles_admin_read`, gated by `current_user_is_admin()`) ALSO continues to grant — three SELECT policies all OR'd together. The Phase 6 body swap of `current_user_is_admin()` means admins / super_admins now reach the same set of rows via two policy paths; that's a no-op redundancy, not a bug.

## Per-role behavior

| Role of caller | Phase 4 self-read | Phase 4 admin-read | Phase 6 users.view | Effective grant |
|---|---|---|---|---|
| Regular `user` | own row only | n/a (not admin) | n/a (no permission) | own row only |
| `moderator` | own row | n/a (not admin-tier) | every row | every row |
| `admin` | own row | every row | every row | every row |
| `super_admin` | own row | every row | every row | every row |

## Invariants

- **Phase 4's `profiles_policies.sql` is NOT edited**. The Phase 6 PR's diff against `supabase/policies/profiles_policies.sql` is empty.
- **The stacked policy is additive**: existing access paths still work.
- **Anon: blocked**. The policy targets `authenticated`; the Phase 4 RLS-default-block covers anon.

## Verification (Supabase MCP `execute_sql`)

```sql
-- 1. As a moderator, cross-user SELECT MUST return the other user's row.
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<moderator-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT user_id, username FROM public.profiles WHERE user_id = '<other-user-uuid>';
-- Expected: 1 row returned (the other user's profile).
RESET ROLE;

-- 2. As a regular user, cross-user SELECT MUST return zero rows.
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<regular-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT user_id, username FROM public.profiles WHERE user_id = '<other-user-uuid>';
-- Expected: 0 rows.

-- 3. As a regular user, self-SELECT MUST still return their own row.
SELECT user_id, username FROM public.profiles WHERE user_id = '<regular-user-uuid>';
-- Expected: 1 row.
RESET ROLE;
```

## Forward references

- Future stacked policies (e.g., Phase 8's `profiles_phase8_listings_view_all` if listings admins need profile reads in some narrow case) follow the same naming convention: `<table>_<phase>_<descriptor>.sql`.
- A future spec MAY consolidate all `profiles` SELECT policies into one combined policy. That spec would need to edit `profiles_policies.sql` and `profiles_phase6_users_view.sql`; the R-05 / R-12 invariants only bind Phase 5 → Phase 6, not arbitrary future consolidation specs.
