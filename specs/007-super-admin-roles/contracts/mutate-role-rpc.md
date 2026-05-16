# Contract: `public.mutate_role(...)` RPC

**Owner**: Phase 7 (`supabase/migrations/20260516120003_create_mutate_role_rpc.sql`).
**Consumers**: `lib/features/super_admin/data/datasources/supabase_role_catalog_datasource.dart` (via `supabase.rpc('mutate_role', params: {...})`). Direct-SQL callers MAY invoke it from Supabase MCP `execute_sql` for verification; the function gates by `current_user_has_permission(...)` so unauthenticated and under-privileged callers are rejected at the same point as in-app callers.
**Stability**: Signature is stable for v1. Argument names and types match the Flutter DTO field names verbatim.

---

## Purpose

Single atomic mutation entry point for the role-row + role-permissions-delta surface. Replaces the IMPLEMENTATION_PLAN-named `mutate_role` Edge Function per Clarifications Session 2026-05-15 Q3 (Phase 7 R-06). The function bundles permission re-check, optimistic-lock check, super_admin permission-set immutability check, role-row mutation, and the role_permissions delta into one implicit transaction. The Phase 7 audit triggers (FR-001/002) fire automatically for each affected row.

## Signature

```sql
CREATE OR REPLACE FUNCTION public.mutate_role(
  op                  TEXT,           -- 'create' | 'update' | 'delete'
  role_id             UUID,           -- NULL for op='create'; required for op IN ('update', 'delete')
  role_key            TEXT,           -- required for op='create'; NULL for op IN ('update', 'delete')
  display_name        JSONB,          -- required for op='create' (at least one of ar/en non-empty); optional for op='update'; NULL for op='delete'
  description         TEXT,           -- optional always
  permission_keys     TEXT[],         -- required for op='create' (may be empty array); optional for op='update' (NULL = no change); NULL for op='delete'
  expected_updated_at TIMESTAMPTZ     -- NULL for op='create'; required for op IN ('update', 'delete')
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth;
```

## Body skeleton

(The full SQL lives in `20260516120003_create_mutate_role_rpc.sql`; this contract captures the semantic structure.)

```sql
DECLARE
  v_super_admin_id UUID;
  v_current_perms TEXT[];
  v_new_role_id UUID;
  v_result JSONB;
BEGIN
  -- ---- 1. Permission re-check by op ----
  IF op = 'create' AND NOT public.current_user_has_permission('roles.create') THEN
    RAISE EXCEPTION 'permission denied: roles.create' USING ERRCODE = '42501';
  ELSIF op = 'update' AND NOT public.current_user_has_permission('roles.update') THEN
    RAISE EXCEPTION 'permission denied: roles.update' USING ERRCODE = '42501';
  ELSIF op = 'delete' AND NOT public.current_user_has_permission('roles.delete') THEN
    RAISE EXCEPTION 'permission denied: roles.delete' USING ERRCODE = '42501';
  END IF;

  -- ---- 2. permissions.manage re-check for permission-set deltas ----
  IF (op IN ('create','update')) AND permission_keys IS NOT NULL
     AND NOT public.current_user_has_permission('permissions.manage') THEN
    RAISE EXCEPTION 'permission denied: permissions.manage' USING ERRCODE = '42501';
  END IF;

  -- ---- 3. Optimistic-lock check (R-07) ----
  IF op IN ('update', 'delete') THEN
    PERFORM 1 FROM public.roles WHERE id = role_id AND updated_at = expected_updated_at FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'role concurrent edit' USING ERRCODE = '40001';
    END IF;
  END IF;

  -- ---- 4. super_admin permission-set immutability (R-08) ----
  IF op = 'update' AND permission_keys IS NOT NULL THEN
    SELECT id INTO v_super_admin_id FROM public.roles WHERE key = 'super_admin';
    IF role_id = v_super_admin_id THEN
      SELECT array_agg(p.key ORDER BY p.key) INTO v_current_perms
      FROM public.role_permissions rp JOIN public.permissions p ON p.id = rp.permission_id
      WHERE rp.role_id = role_id;
      IF v_current_perms IS DISTINCT FROM (SELECT array_agg(k ORDER BY k) FROM unnest(permission_keys) k) THEN
        RAISE EXCEPTION 'super_admin permission set is immutable' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  -- ---- 5. Op-specific execution ----
  IF op = 'create' THEN
    -- (i) Reject role_key = 'super_admin' (would conflict; explicit error is friendlier than UNIQUE)
    IF role_key = 'super_admin' THEN
      RAISE EXCEPTION 'role key reserved: super_admin' USING ERRCODE = '23505';
    END IF;

    -- (ii) Insert role row (is_system hard-coded FALSE)
    INSERT INTO public.roles (key, display_name, description, is_system)
    VALUES (role_key, display_name, description, false)
    RETURNING id INTO v_new_role_id;

    -- (iii) Insert role_permissions rows for the seed
    INSERT INTO public.role_permissions (role_id, permission_id)
    SELECT v_new_role_id, p.id FROM public.permissions p WHERE p.key = ANY(permission_keys);

    -- (iv) Build result
    SELECT jsonb_build_object('role_id', v_new_role_id, 'key', role_key, 'display_name', display_name,
                              'description', description, 'permission_keys', permission_keys,
                              'updated_at', (SELECT updated_at FROM public.roles WHERE id = v_new_role_id))
    INTO v_result;

  ELSIF op = 'update' THEN
    -- (i) Update role row (display_name and description are nullable -- COALESCE preserves existing)
    UPDATE public.roles SET
      display_name = COALESCE(mutate_role.display_name, roles.display_name),
      description  = COALESCE(mutate_role.description,  roles.description)
    WHERE id = role_id;
    -- set_updated_at trigger advances roles.updated_at automatically.

    -- (ii) Apply permission_keys delta (server-side per R-16)
    IF permission_keys IS NOT NULL THEN
      -- Delete keys that are in current set but not in new set
      DELETE FROM public.role_permissions rp
      WHERE rp.role_id = role_id
        AND rp.permission_id NOT IN (SELECT id FROM public.permissions WHERE key = ANY(permission_keys));
      -- Insert keys that are in new set but not in current set
      INSERT INTO public.role_permissions (role_id, permission_id)
      SELECT role_id, p.id FROM public.permissions p
      WHERE p.key = ANY(permission_keys)
        AND NOT EXISTS (SELECT 1 FROM public.role_permissions rp2 WHERE rp2.role_id = mutate_role.role_id AND rp2.permission_id = p.id);
    END IF;

    -- (iii) Build result
    SELECT jsonb_build_object('role_id', role_id, 'key', r.key, 'display_name', r.display_name,
                              'description', r.description,
                              'permission_keys', (SELECT array_agg(p.key) FROM public.role_permissions rp
                                                  JOIN public.permissions p ON p.id = rp.permission_id
                                                  WHERE rp.role_id = mutate_role.role_id),
                              'updated_at', r.updated_at)
    INTO v_result FROM public.roles r WHERE r.id = role_id;

  ELSIF op = 'delete' THEN
    -- (i) Capture role_key for the result (after the row is gone, we can't read it)
    DECLARE v_role_key TEXT;
    BEGIN
      SELECT key INTO v_role_key FROM public.roles WHERE id = role_id;
    END;

    -- (ii) Delete the row (cascades to role_permissions; FK RESTRICT on user_roles raises if any user holds it)
    DELETE FROM public.roles WHERE id = role_id;
    -- enforce_role_system_immutability trigger fires BEFORE this and raises 42501 if is_system=true.

    -- (iii) Build result
    v_result := jsonb_build_object('role_id', role_id, 'key', v_role_key, 'deleted', true);

  ELSE
    RAISE EXCEPTION 'unknown op: %', op USING ERRCODE = '22023';
  END IF;

  RETURN v_result;
END;
```

## Argument validation

| Argument | Required for | Validation |
|---|---|---|
| `op` | always | Must be `'create'`, `'update'`, or `'delete'`; else `22023 invalid_parameter_value`. |
| `role_id` | `update`, `delete` | Must reference an existing `roles.id`; else `40001` (optimistic-lock check fails because no row matches). |
| `role_key` | `create` | Must be unique (`UNIQUE` constraint enforces); cannot be `'super_admin'` (explicit `23505`). |
| `display_name` | `create` | Must have at least one of `->>'ar'` or `->>'en'` non-empty; else `22023`. |
| `permission_keys` | `create` | Every key MUST exist in `permissions.key`; else the `INSERT ... SELECT ... WHERE key = ANY(...)` simply misses unknown keys (a quiet drop). Client SHOULD validate locally first; server-side strict validation is deferred. |
| `expected_updated_at` | `update`, `delete` | Must match the current `roles.updated_at`; else `40001`. |

## Error contract (R-14 catalog excerpt)

| SQLSTATE | Reason | Structured ARB key |
|---|---|---|
| `42501` | Caller lacks `roles.create` / `roles.update` / `roles.delete` | `errorRolePermissionDenied` |
| `42501` | Caller lacks `permissions.manage` (when permission_keys delta non-empty) | `errorPermissionsManageDenied` |
| `42501` | super_admin permission-set immutability violated (R-08) | `errorSuperAdminPermissionsImmutable` |
| `42501` | System-role immutability trigger fires on DELETE or `key` rename | `errorSystemRoleImmutable` |
| `40001` | Optimistic-lock conflict — `expected_updated_at` ≠ current `roles.updated_at` | `errorRoleEditConflict` |
| `23503` | DELETE blocked by `user_roles.role_id ON DELETE RESTRICT` (users still hold the role) | `errorRoleHasUsers` |
| `23505` | Duplicate `roles.key` on create OR reserved key (`super_admin`) | `errorRoleKeyDuplicate` |
| `22023` | Unknown `op` value | `errorInvalidOp` |

## Audit-trail behavior

Per R-12 (one audit row per mutation row):

- **`op='create'` with N permissions**: 1 `role.created` + N `role_permission.granted` audit rows.
- **`op='update'` with display_name change only**: 1 `role.updated` audit row; the `set_updated_at` trigger advances `updated_at` (visible in the `after_state` JSON).
- **`op='update'` with display_name change + K added + L removed permissions**: 1 `role.updated` + K `role_permission.granted` + L `role_permission.revoked` audit rows.
- **`op='delete'`**: 1 `role.deleted` + M `role_permission.revoked` (cascade) audit rows, where M is the role's permission count at delete-time.

`actor_user_id` carries `auth.uid()` for in-app calls; NULL for `postgres`-session direct-SQL calls.

## RPC permission grant

```sql
-- In 20260516120005_phase7_advisor_hardening.sql:
REVOKE EXECUTE ON FUNCTION public.mutate_role(TEXT, UUID, TEXT, JSONB, TEXT, TEXT[], TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mutate_role(TEXT, UUID, TEXT, JSONB, TEXT, TEXT[], TIMESTAMPTZ) TO authenticated;
```

Anon clients cannot invoke. Authenticated clients invoke; the function's permission re-check is the gate.

## Verification (Supabase MCP `execute_sql`)

```sql
-- 1. Authenticated as super_admin: create a custom role
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<super_admin-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;

SELECT public.mutate_role(
  op := 'create',
  role_id := NULL,
  role_key := 'finance',
  display_name := '{"ar":"محاسبة","en":"Finance"}'::jsonb,
  description := 'Finance role with currencies-only access',
  permission_keys := ARRAY['currencies.manage'],
  expected_updated_at := NULL
);
-- Expected: JSONB result with role_id, key='finance', permission_keys=['currencies.manage'].

-- 2. Verify audit rows
SELECT action FROM public.audit_logs WHERE created_at > now() - interval '1 minute' ORDER BY created_at;
-- Expected: role.created, role_permission.granted (in that order).

-- 3. Attempt an update with stale token (force a 40001)
SELECT public.mutate_role(
  op := 'update',
  role_id := (SELECT id FROM public.roles WHERE key = 'finance'),
  role_key := NULL,
  display_name := NULL,
  description := 'updated',
  permission_keys := NULL,
  expected_updated_at := '1970-01-01'::timestamptz
);
-- Expected: ERROR 40001 (serialization_failure) 'role concurrent edit'.

-- 4. Attempt to mutate super_admin's permission set (force a 42501 R-08)
SELECT public.mutate_role(
  op := 'update',
  role_id := (SELECT id FROM public.roles WHERE key = 'super_admin'),
  role_key := NULL,
  display_name := NULL,
  description := NULL,
  permission_keys := ARRAY['currencies.manage']::TEXT[],  -- subset, not full catalog
  expected_updated_at := (SELECT updated_at FROM public.roles WHERE key = 'super_admin')
);
-- Expected: ERROR 42501 'super_admin permission set is immutable'.

-- 5. Cleanup
SELECT public.mutate_role(
  op := 'delete',
  role_id := (SELECT id FROM public.roles WHERE key = 'finance'),
  role_key := NULL, display_name := NULL, description := NULL, permission_keys := NULL,
  expected_updated_at := (SELECT updated_at FROM public.roles WHERE key = 'finance')
);
-- Expected: JSONB result with deleted=true; the cascade fires role_permission.revoked audit rows.

RESET ROLE;

-- 6. Non-super_admin attempt (should fail at step 1)
DO $$ BEGIN PERFORM set_config('request.jwt.claims', '{"sub":"<regular-user-uuid>","role":"authenticated"}', true); END $$;
SET LOCAL ROLE authenticated;
SELECT public.mutate_role(op := 'create', role_id := NULL, role_key := 'test', ...);
-- Expected: ERROR 42501 'permission denied: roles.create'.
RESET ROLE;
```

## Forward references

- The Edge Function path named in IMPLEMENTATION_PLAN.md §Phase 7 is deferred. A future spec that needs Edge Function infrastructure (e.g., Phase 22 FCM fan-out) MAY revisit whether to migrate `mutate_role` into an Edge Function for unified observability with other Edge Functions; current call:RPC is the v1 stance.
- A future spec MAY relax the super_admin permission-set immutability (R-08) if a use case for it emerges (e.g., a "carve out a `users.view_pii` permission key" workflow). The relaxation would change the R-08 check; the contract here would update.
