# Contract: `public.revoke_role_from_user(...)` RPC

**Owner**: Phase 7 (`supabase/migrations/20260516120004_create_user_role_assignment_rpcs.sql`).
**Consumers**: `lib/features/super_admin/data/datasources/supabase_user_search_datasource.dart` (via `supabase.rpc('revoke_role_from_user', params: {...})`).
**Stability**: Signature is stable for v1.

---

## Purpose

In-app entry point for revoking a role from a user. Enforces:
- `permissions.manage` permission re-check server-side.
- The unconditional super_admin self-revoke block (R-05) server-side.
- Audit-trail emission via Phase 6's existing `trg_user_roles_audit_revoked` trigger (unchanged).

## Signature

```sql
CREATE OR REPLACE FUNCTION public.revoke_role_from_user(
  target_user_id UUID,
  target_role_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth;
```

## Body skeleton

```sql
DECLARE
  v_super_admin_id UUID;
  v_rows_affected  INTEGER;
BEGIN
  -- 1. permission re-check
  IF NOT public.current_user_has_permission('permissions.manage') THEN
    RAISE EXCEPTION 'permission denied: permissions.manage' USING ERRCODE = '42501';
  END IF;

  -- 2. Unconditional super_admin self-revoke block (R-05)
  SELECT id INTO v_super_admin_id FROM public.roles WHERE key = 'super_admin';
  IF target_role_id = v_super_admin_id AND auth.uid() = target_user_id THEN
    RAISE EXCEPTION 'super_admin self-revoke forbidden' USING ERRCODE = '42501';
  END IF;

  -- 3. Delete (Phase 6's trg_user_roles_audit_revoked fires automatically)
  DELETE FROM public.user_roles
  WHERE user_id = target_user_id AND role_id = target_role_id;
  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

  IF v_rows_affected = 0 THEN
    RAISE EXCEPTION 'user does not hold role' USING ERRCODE = '02000';  -- no_data
  END IF;

  -- 4. Return the revocation summary
  RETURN jsonb_build_object(
    'user_id', target_user_id,
    'role_id', target_role_id,
    'revoked_by', auth.uid(),
    'revoked_at', now()
  );
END;
```

## Error contract (R-14 catalog excerpt)

| SQLSTATE | Reason | Structured ARB key |
|---|---|---|
| `42501` | Caller lacks `permissions.manage` | `errorRevokePermissionDenied` |
| `42501` | Self-revoke of super_admin attempted (R-05) | `errorSuperAdminSelfRevokeForbidden` |
| `02000` | User does not hold the role (no_data; client can treat as success-equivalent or surface as informational) | `errorUserDoesNotHoldRole` |

## RPC permission grant

```sql
-- In 20260516120005_phase7_advisor_hardening.sql:
REVOKE EXECUTE ON FUNCTION public.revoke_role_from_user(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_role_from_user(UUID, UUID) TO authenticated;
```

## Audit-trail behavior

Phase 6's `trg_user_roles_audit_revoked` fires automatically on the DELETE — one `user_role.revoked` audit row per call. `actor_user_id = auth.uid()` (the super_admin); `target_id = target_user_id`. The audit row's `before_state` JSON contains the full deleted row.

## Verification (Supabase MCP `execute_sql`)

```sql
-- 1. Authenticated as super_admin: revoke a non-super_admin role
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<super_admin-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;

SELECT public.revoke_role_from_user(
  target_user_id := '<target-uuid>',
  target_role_id := (SELECT id FROM public.roles WHERE key = 'moderator')
);
-- Expected: JSONB result; user_roles row deleted.

-- 2. Verify the audit row
SELECT action, actor_user_id, target_id FROM public.audit_logs
WHERE action = 'user_role.revoked' ORDER BY created_at DESC LIMIT 1;
-- Expected: actor_user_id = <super_admin-uuid>; target_id = <target-uuid>.

-- 3. Attempt to self-revoke super_admin
SELECT public.revoke_role_from_user(
  target_user_id := '<super_admin-uuid>',  -- same as auth.uid()
  target_role_id := (SELECT id FROM public.roles WHERE key = 'super_admin')
);
-- Expected: ERROR 42501 'super_admin self-revoke forbidden'.

-- 4. Revoke a non-existent assignment
SELECT public.revoke_role_from_user(
  target_user_id := '<target-uuid>',
  target_role_id := (SELECT id FROM public.roles WHERE key = 'moderator')  -- already revoked in step 1
);
-- Expected: ERROR 02000 'user does not hold role'.

-- 5. Revoke another super_admin's super_admin role (allowed — only self-revoke is blocked)
-- Setup: ensure another super_admin user_role row exists for <other-super_admin-uuid>
SELECT public.revoke_role_from_user(
  target_user_id := '<other-super_admin-uuid>',  -- different from auth.uid()
  target_role_id := (SELECT id FROM public.roles WHERE key = 'super_admin')
);
-- Expected: JSONB result; the other super_admin's row deleted.

RESET ROLE;

-- 6. Non-super_admin attempt
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<regular-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT public.revoke_role_from_user(target_user_id := '<some-uuid>', target_role_id := (SELECT id FROM public.roles WHERE key = 'user'));
-- Expected: ERROR 42501 'permission denied: permissions.manage'.
RESET ROLE;
```

## Self-revoke block: rationale and edge cases

Per R-05 (locked Session 2026-05-15 Q2), self-revocation is blocked unconditionally regardless of the number of remaining super_admins. The simpler equality check (`auth.uid() = target_user_id`) is preferable to a count-aware guard for two reasons:

1. **No count query in the critical path** — the alternative would need `SELECT count(*) FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE r.key = 'super_admin'` before every revoke; the unconditional rule avoids it.
2. **No race on the count** — if two super_admins try to self-revoke simultaneously and the count is 2, both would see "2 remaining" and both would proceed, leaving zero super_admins.

The trade-off: a super_admin who wants to step down must ask another super_admin to revoke them. For a project with only one super_admin, the recovery path is the same Supabase MCP `execute_sql` running-as-`postgres` recipe used for the first-super_admin bootstrap.

## Forward references

- A future spec MAY relax this if a clearer use case emerges. The relaxation would change the R-05 server check; the contract here would update.
- A future spec MAY introduce a count-aware safety net for non-super_admin role self-revoke (e.g., the last admin self-revoking `admin`). Phase 7 does NOT need this — the operational risk is bounded by the super_admin's ability to grant the role back via `AssignRolePage`.
