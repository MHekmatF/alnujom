# Contract: `public.assign_role_to_user(...)` RPC

**Owner**: Phase 7 (`supabase/migrations/20260516120004_create_user_role_assignment_rpcs.sql`).
**Consumers**: `lib/features/super_admin/data/datasources/supabase_user_search_datasource.dart` (via `supabase.rpc('assign_role_to_user', params: {...})`).
**Stability**: Signature is stable for v1.

---

## Purpose

In-app entry point for granting a role to a user. Enforces:
- `permissions.manage` permission re-check server-side.
- The two-step super_admin grant confirmation (R-04) server-side via the `confirmation_token` argument.
- Audit-trail emission via Phase 6's existing `trg_user_roles_audit_granted` trigger (unchanged).

## Signature

```sql
CREATE OR REPLACE FUNCTION public.assign_role_to_user(
  target_user_id     UUID,
  target_role_id     UUID,
  confirmation_token TEXT  -- required (non-NULL) when target_role_id references super_admin; ignored otherwise
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
  v_target_phone   TEXT;
  v_target_username TEXT;
BEGIN
  -- 1. permission re-check
  IF NOT public.current_user_has_permission('permissions.manage') THEN
    RAISE EXCEPTION 'permission denied: permissions.manage' USING ERRCODE = '42501';
  END IF;

  -- 2. Two-step super_admin grant confirmation (R-04)
  SELECT id INTO v_super_admin_id FROM public.roles WHERE key = 'super_admin';
  IF target_role_id = v_super_admin_id THEN
    IF confirmation_token IS NULL THEN
      RAISE EXCEPTION 'super_admin grant requires confirmation_token' USING ERRCODE = '42501';
    END IF;
    SELECT phone, username INTO v_target_phone, v_target_username
    FROM public.profiles WHERE user_id = target_user_id;
    IF confirmation_token <> v_target_phone AND confirmation_token <> v_target_username THEN
      RAISE EXCEPTION 'super_admin grant confirmation failed' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- 3. Insert (Phase 6's trg_user_roles_audit_granted fires automatically)
  INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
  VALUES (target_user_id, target_role_id, auth.uid(), now());
  -- UNIQUE(user_id, role_id) raises 23505 if user already holds the role.

  -- 4. Return the assignment
  RETURN jsonb_build_object(
    'user_id', target_user_id,
    'role_id', target_role_id,
    'granted_by', auth.uid(),
    'granted_at', now()
  );
END;
```

## Error contract (R-14 catalog excerpt)

| SQLSTATE | Reason | Structured ARB key |
|---|---|---|
| `42501` | Caller lacks `permissions.manage` | `errorAssignPermissionDenied` |
| `42501` | super_admin grant with NULL `confirmation_token` | `errorSuperAdminGrantConfirmationRequired` |
| `42501` | super_admin grant with `confirmation_token` mismatch (R-04) | `errorSuperAdminGrantConfirmationFailed` |
| `23505` | User already holds the role (`UNIQUE(user_id, role_id)`) | `errorUserAlreadyHoldsRole` |

## RPC permission grant

```sql
-- In 20260516120005_phase7_advisor_hardening.sql:
REVOKE EXECUTE ON FUNCTION public.assign_role_to_user(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_role_to_user(UUID, UUID, TEXT) TO authenticated;
```

## Audit-trail behavior

Phase 6's `trg_user_roles_audit_granted` fires automatically on the INSERT — one `user_role.granted` audit row per call. `actor_user_id = auth.uid()` (the super_admin); `target_id = target_user_id`. The audit row's `after_state` JSON contains the full inserted row (including `granted_by`).

## Verification (Supabase MCP `execute_sql`)

```sql
-- 1. Authenticated as super_admin: grant a non-super_admin role
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<super_admin-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;

SELECT public.assign_role_to_user(
  target_user_id := '<target-uuid>',
  target_role_id := (SELECT id FROM public.roles WHERE key = 'moderator'),
  confirmation_token := NULL  -- not super_admin grant; ignored
);
-- Expected: JSONB result; user_roles row inserted.

-- 2. Verify the audit row
SELECT action, actor_user_id, target_id FROM public.audit_logs
WHERE action = 'user_role.granted' ORDER BY created_at DESC LIMIT 1;
-- Expected: actor_user_id = <super_admin-uuid>; target_id = <target-uuid>.

-- 3. Attempt super_admin grant without confirmation_token
SELECT public.assign_role_to_user(
  target_user_id := '<target-uuid>',
  target_role_id := (SELECT id FROM public.roles WHERE key = 'super_admin'),
  confirmation_token := NULL
);
-- Expected: ERROR 42501 'super_admin grant requires confirmation_token'.

-- 4. Attempt super_admin grant with wrong confirmation_token
SELECT public.assign_role_to_user(
  target_user_id := '<target-uuid>',
  target_role_id := (SELECT id FROM public.roles WHERE key = 'super_admin'),
  confirmation_token := 'wrong'
);
-- Expected: ERROR 42501 'super_admin grant confirmation failed'.

-- 5. Successful super_admin grant with correct phone match
SELECT public.assign_role_to_user(
  target_user_id := '<target-uuid>',
  target_role_id := (SELECT id FROM public.roles WHERE key = 'super_admin'),
  confirmation_token := (SELECT phone FROM public.profiles WHERE user_id = '<target-uuid>')
);
-- Expected: JSONB result; new super_admin user_roles row inserted.

-- 6. Attempt duplicate grant
SELECT public.assign_role_to_user(
  target_user_id := '<target-uuid>',
  target_role_id := (SELECT id FROM public.roles WHERE key = 'super_admin'),
  confirmation_token := (SELECT phone FROM public.profiles WHERE user_id = '<target-uuid>')
);
-- Expected: ERROR 23505 (unique_violation).

RESET ROLE;

-- 7. Non-super_admin attempt
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<regular-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT public.assign_role_to_user(target_user_id := '<some-uuid>', target_role_id := (SELECT id FROM public.roles WHERE key = 'user'), confirmation_token := NULL);
-- Expected: ERROR 42501 'permission denied: permissions.manage'.
RESET ROLE;
```

## Defense-in-depth note

The UI also enforces the two-step super_admin confirmation client-side (`SuperAdminGrantConfirmationDialog` widget). The server-side check is the binding gate; the client-side widget exists to give a coherent UX, not to be the security boundary.

## Forward references

- A future spec MAY introduce additional grant-time checks (e.g., a `confirmation_token` requirement for any grant of a role with `permissions.manage`). The signature here is forward-extensible — adding required arguments to a SECURITY DEFINER function is a breaking change for callers; non-required arguments can be appended with default NULL.
