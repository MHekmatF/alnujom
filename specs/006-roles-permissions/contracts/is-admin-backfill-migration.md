# Contract: `is_admin` Backfill + Column Drop Migration

**Owner**: Phase 6 (`supabase/migrations/20260515120007_backfill_is_admin_and_drop.sql`).
**Consumers**: the Supabase migration tool (one-shot apply). The contract describes the migration body's invariants and the post-migration schema state.
**Stability**: One-shot migration. After it runs successfully on the remote project, it MUST NOT be edited; future fixes use new migrations.

---

## Purpose

The riskiest single migration in Phase 6. Combines four steps that must land atomically:

1. Backfill the `admin` role for every prior `is_admin=true` user.
2. Backfill the `user` role for every existing profile (establishes the "every user holds at least one role" invariant).
3. Drop the `profiles.is_admin` column.
4. Rewrite the `enforce_profile_status_admin_only()` trigger function so it no longer references the dropped column.

The Supabase migration tool wraps the migration body in an implicit transaction; if any step fails, the whole migration rolls back.

## SQL body

```sql
-- Phase 6 — Backfill is_admin column to user_roles and drop the column.
-- Single transactional migration; all five effects land atomically or roll back together.

-- Step 1: Backfill the `admin` role for every prior is_admin=true user.
INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
SELECT p.user_id, (SELECT id FROM public.roles WHERE key = 'admin'), NULL, now()
FROM public.profiles p
WHERE p.is_admin = TRUE
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Step 2: Backfill the `user` role for every existing profile.
INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
SELECT p.user_id, (SELECT id FROM public.roles WHERE key = 'user'), NULL, now()
FROM public.profiles p
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Step 3: Drop the column.
ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_admin;

-- Step 4: Rewrite the trigger function so it no longer references is_admin.
CREATE OR REPLACE FUNCTION public.enforce_profile_status_admin_only()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF (
    (NEW.account_status IS DISTINCT FROM OLD.account_status
     OR NEW.publisher_status IS DISTINCT FROM OLD.publisher_status)
    AND NOT public.current_user_is_admin()
    AND auth.role() <> 'service_role'
  ) THEN
    RAISE EXCEPTION 'only admins may change account_status or publisher_status'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;
```

## Step ordering rationale (R-11)

| Step | Depends on | Why this order |
|------|-----------|----------------|
| 1 (backfill admin) | `roles` seed (migration 1) + `is_admin` column (still exists from Phase 5) | Must read `profiles.is_admin` BEFORE the column is dropped. |
| 2 (backfill user) | `roles` seed | Independent of `is_admin`; placed second for narrative clarity (admin first, then implicit user). |
| 3 (drop column) | Step 1 complete | Once step 1 is done, no further step needs to read `is_admin`. |
| 4 (rewrite trigger function) | Step 3 done | The function body references `current_user_is_admin()` — which now resolves to the role-membership check (post migration 6). The function body no longer references `is_admin` directly, so the column drop must precede this rewrite to avoid a brief window where the function definition references a still-present column (which would be valid but confusing). |

## Invariants

- **Idempotent**: re-running the migration body is safe.
  - Step 1 / Step 2: `ON CONFLICT (user_id, role_id) DO NOTHING`.
  - Step 3: `DROP COLUMN IF EXISTS`.
  - Step 4: `CREATE OR REPLACE FUNCTION`.
- **Atomic**: the four steps are wrapped in the migration tool's implicit transaction; partial failure rolls back.
- **No data loss**: every `is_admin=true` user is converted to an `admin` role assignment BEFORE the column is dropped. SC-002 / SC-004 verify the conversion count.
- **No behavior change for prior admins**: post-migration, `current_user_is_admin()` returns the same value for every prior admin (the body swap from migration 6 + the backfill from this migration ensure semantic continuity).

## Audit trail (via FR-010 audit trigger on `user_roles`)

- Step 1 produces N audit-log rows (one per `is_admin=true` user) via `trg_user_roles_audit_granted`, with `action='user_role.granted'`, `actor_user_id=NULL` (the migration runs as `postgres` — no `auth.uid()`).
- Step 2 produces M audit-log rows (one per existing profile) via the same trigger, with `action='user_role.granted'`, `actor_user_id=NULL`.
- Steps 3 and 4 produce no audit rows (the audit triggers are only on `user_roles`, not on `profiles` or function definitions).

## Verification (Supabase MCP `execute_sql`)

Pre-migration capture:
```sql
SELECT count(*) FROM public.profiles WHERE is_admin = TRUE;
-- Save as N_pre.

SELECT count(*) FROM public.profiles;
-- Save as M_total.
```

Post-migration:
```sql
-- Step 1 result: admin role assignment count ≥ N_pre.
SELECT count(DISTINCT ur.user_id) FROM public.user_roles ur
JOIN public.roles r ON r.id = ur.role_id WHERE r.key = 'admin';
-- Expected: ≥ N_pre

-- Step 2 result: every profile has a user-role assignment.
SELECT count(*) FROM public.profiles p WHERE NOT EXISTS (
  SELECT 1 FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id
  WHERE ur.user_id = p.user_id AND r.key = 'user'
);
-- Expected: 0

-- Step 3 result: column is gone.
SELECT 1 FROM information_schema.columns
WHERE table_schema='public' AND table_name='profiles' AND column_name='is_admin';
-- Expected: 0 rows

SELECT is_admin FROM public.profiles LIMIT 1;
-- Expected: ERROR 42703 'column "is_admin" does not exist'

-- Step 4 result: trigger function body no longer mentions is_admin.
SELECT pg_get_functiondef('public.enforce_profile_status_admin_only()'::regprocedure);
-- Expected: definition does NOT contain 'is_admin'.

-- Audit trail: count of system-grant rows from the backfill.
SELECT count(*) FROM public.audit_logs WHERE action = 'user_role.granted' AND actor_user_id IS NULL;
-- Expected: N_pre + M_total (admin grants + user grants).
```

## Rollback strategy

If the migration fails:
- The implicit transaction rolls back. `profiles.is_admin` still exists; `user_roles` has no new rows.
- The Phase 5 schema is fully intact; no half-state.

If the migration succeeds but later reveals a problem (e.g., a Phase 5 policy was missed in the audit and references `is_admin` directly):
- A new "rollforward" migration adds the column back, copies admin-role users back to `is_admin=true`, and re-creates the Phase 5 trigger function. This is not planned but documented as the recovery path.

## Forward references

- This migration is the LAST migration in v1 that touches the `is_admin` legacy column. Future specs MUST NOT add a new `is_admin` column to any table — permission gating is via `current_user_has_permission(<key>)` from Phase 6 onward.
