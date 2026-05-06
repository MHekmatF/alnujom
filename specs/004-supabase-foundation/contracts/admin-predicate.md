# Contract: `current_user_is_admin()` Admin Predicate Helper

**Owner**: Phase 4 (`supabase/migrations/20260506120002_create_profiles.sql` defines the placeholder function — moved from the original `20260506120005_enable_rls_default.sql` plan because R-12's `enforce_profile_status_admin_only` trigger calls this helper from `0002`).
**Consumers**: Every RLS policy in Phase 4 that gates admin-readable or admin-writable rows. Later phases either reuse the helper as-is or **only redefine its body** — they MUST NOT swap call sites to a different helper.
**Stability**: **The signature is stable across the entire v1 lifecycle.** The body changes phase-by-phase; the function name, return type, and parameter list do not.

---

## Purpose

A single, swappable predicate that every admin-gated policy calls. Centralizing the predicate behind one function realizes the spec's binding constraint: replacing the placeholder MUST NOT require touching every Phase 4 policy file.

## Function

```
current_user_is_admin() RETURNS BOOLEAN
```

- **Language**: SQL (Phase 4 placeholder; later phases may switch to PL/pgSQL if their body needs control flow).
- **Security**: `SECURITY INVOKER` (the default — see R-05 rationale).
- **Volatility**: `STABLE` (same input session ⇒ same output within a statement).

## Phase 4 body

```sql
CREATE OR REPLACE FUNCTION current_user_is_admin() RETURNS BOOLEAN
LANGUAGE SQL STABLE AS $$
  SELECT FALSE;
$$;
```

Phase 4 has no admin role yet. Every admin-gated policy that calls this function evaluates to FALSE for every caller, which is the intended behavior — admin-gated rows are read-blocked until Phase 5 introduces the interim `is_admin` flag.

## Phase replacement plan

| Phase | Body | Notes |
|---|---|---|
| 4 | `SELECT FALSE;` | This phase. |
| 5 | `SELECT (SELECT is_admin FROM profiles WHERE user_id = auth.uid());` | Phase 5 introduces the `is_admin` boolean column on `profiles`. |
| 6 | `SELECT current_user_has_permission('users.view');` (or whatever anchor permission Phase 6's spec chooses) | Phase 6 ships the role/permission system and the helper `current_user_has_permission(perm_key TEXT) RETURNS BOOLEAN`. The Phase 6 migration also backfills existing `is_admin` users to the `admin` role and drops the `profiles.is_admin` column. |

**Implementation rule**: Each phase's swap is a single `CREATE OR REPLACE FUNCTION current_user_is_admin() …` migration statement. No policy file is touched. No call site changes.

## Policies and triggers that call this function (Phase 4)

- **Policies**:
  - `profiles_select_admin_status` (admin-read on status fields).
  - `profiles_update_admin_status` (admin-write of `account_status`, `publisher_status`).
  - `audit_logs_select_admin` (admin-read of all rows).
  
  The exact policy SQL lives in `supabase/policies/profiles_policies.sql` and `supabase/policies/audit_logs_policies.sql`, inlined into `20260506120005_enable_rls_default.sql` per R-02.

- **Trigger**: `enforce_profile_status_admin_only()` (the R-12 column-level enforcement function) calls `current_user_is_admin()` to decide whether a non-privileged session may change `profiles.account_status` / `publisher_status`. Defined in `20260506120002_create_profiles.sql` alongside the helper itself.

**Note on RLS column-level limits**: Postgres RLS policies are row-level, not column-level. The `profiles_update_admin_status` policy alone cannot prevent a self-update policy from also matching and allowing the change. Column-level enforcement is delivered by the R-12 trigger, not the policy. The policy exists so admin queries can target the row at all under RLS; the trigger exists so the change actually goes through only for admins.

## What MUST NOT happen

- Later phases MUST NOT add a parallel admin helper (`current_user_is_super_admin`, `is_admin_user`, …) and silently switch some policies to call it. New helpers are fine; switching call sites is not — it splits the source of truth.
- A policy MUST NOT inline an admin check (`USING (auth.uid() IN (SELECT user_id FROM profiles WHERE is_admin))`) that bypasses the helper. The helper is the ONLY place admin-determination logic lives.
- The helper MUST NOT be `SECURITY DEFINER` — running it with elevated privileges would let it return TRUE in contexts where the calling session isn't actually admin (the function would read `profiles` as the function's owner, not the caller).

## Verification (Phase 4 quickstart)

```sql
-- 1. Confirm the function exists with the right signature.
SELECT proname, prorettype::regtype, proargtypes::regtype[]
  FROM pg_proc WHERE proname = 'current_user_is_admin';
-- Expect: proname = 'current_user_is_admin', prorettype = 'boolean', no args.

-- 2. Confirm Phase 4 body returns FALSE for every caller.
SELECT current_user_is_admin();
-- Expect: f / false.

-- 3. Confirm a normal authenticated user cannot read audit_logs.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"<some-real-user-id>","role":"authenticated"}', true);
SELECT COUNT(*) FROM audit_logs;
-- Expect: 0 (RLS blocks; current_user_is_admin() = FALSE).
RESET ROLE;
```
