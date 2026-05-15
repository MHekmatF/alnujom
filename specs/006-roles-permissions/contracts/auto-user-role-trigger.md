# Contract: Auto-`user`-Role Trigger on `profiles` Insert

**Owner**: Phase 6 (`supabase/migrations/20260515120004_create_user_roles.sql`).
**Consumers**: implicit — fires for every `profiles` INSERT, including Phase 4's auto-provision trigger from `auth.users` and any future privileged INSERT.
**Stability**: Function and trigger names are stable for v1. The role assigned (`user`) is the canonical default.

---

## Purpose

Maintains the invariant "every signed-in user has at least one `user_roles` row pointing at the `user` role". Combined with Phase 6's FR-011 backfill (which populates the row for every existing profile), the invariant holds from Phase 6 deploy time onward.

## Function

```sql
CREATE OR REPLACE FUNCTION public.auto_create_user_role_for_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
  VALUES (
    NEW.user_id,
    (SELECT id FROM public.roles WHERE key = 'user'),
    NULL,
    now()
  )
  ON CONFLICT (user_id, role_id) DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.auto_create_user_role_for_user() FROM PUBLIC, anon;

DROP TRIGGER IF EXISTS trg_profiles_auto_user_role ON public.profiles;
CREATE TRIGGER trg_profiles_auto_user_role
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.auto_create_user_role_for_user();
```

## Semantics

- Fires AFTER INSERT on `profiles` — after Phase 4's auto-provision trigger creates the row.
- `SECURITY DEFINER`: the function runs as the migration owner (`postgres`), so the INSERT into `user_roles` bypasses RLS. `auth.uid()` (the new user) doesn't yet have any permission that would let them write to `user_roles` themselves.
- `granted_by = NULL`: system grant. Distinguishable in audit logs from in-app grants.
- `granted_at = now()`: timestamp of the assignment.
- `ON CONFLICT DO NOTHING`: idempotent. If the FR-011 backfill happens to have already inserted a `user`-role row for this user (e.g., if the migration re-runs), the trigger no-ops.
- Returns `NEW` so the `profiles` INSERT proceeds normally.

## Invariants

- **Every new profile inserted post-Phase-6 has a `user`-role assignment**.
- **The trigger is idempotent**: re-running migrations doesn't error.
- **The trigger emits one audit-log row** via the FR-010 audit trigger on `user_roles` (the INSERT fires `trg_user_roles_audit_granted`; action: `user_role.granted`; `actor_user_id`: `auth.uid()` of the signup caller, which is the brand-new user themselves; for the migration-context backfill, `actor_user_id` is NULL since there's no JWT).

## Verification (Supabase MCP `execute_sql`)

```sql
-- 1. Sign up a new test user via Supabase Auth (or via auth.users INSERT for testing).
-- After the signup chain completes (auth.users → profiles → user_roles via two triggers):

SELECT count(*) FROM public.user_roles ur
JOIN public.roles r ON r.id = ur.role_id
WHERE ur.user_id = '<new-user-uuid>' AND r.key = 'user';
-- Expected: 1

-- 2. Check the audit-log row was emitted
SELECT action, actor_user_id FROM public.audit_logs
WHERE action LIKE 'user_role.%' AND target_id = '<new-user-uuid>'
ORDER BY created_at DESC LIMIT 1;
-- Expected: action='user_role.granted'; actor_user_id = the new user's UUID (a normal signup carries the user's JWT into the trigger context).
```

## Forward references

- Phase 7's super-admin UI may extend the auto-assignment logic (e.g., for users in the `agency_admin` role, also auto-grant the agency-member role). The trigger function would gain a conditional or be replaced with a more sophisticated dispatch. The signature stays the same.
