-- Phase 7: SECURITY DEFINER role mutation RPC.
-- Source: specs/007-super-admin-roles/contracts/mutate-role-rpc.md
-- FR-008. Encodes Clarifications Q3 (SQL RPC), Q4 (optimistic locking),
-- and Q5 (super_admin permission-set immutability).

CREATE OR REPLACE FUNCTION public.mutate_role(
  op                  TEXT,
  role_id             UUID,
  role_key            TEXT,
  display_name        JSONB,
  description         TEXT,
  permission_keys     TEXT[],
  expected_updated_at TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_role_id UUID;
  v_role_key TEXT;
  v_current_perms TEXT[] := ARRAY[]::TEXT[];
  v_requested_perms TEXT[] := ARRAY[]::TEXT[];
  v_result JSONB;
BEGIN
  IF op = 'create' AND NOT public.current_user_has_permission('roles.create') THEN
    RAISE EXCEPTION 'permission denied: roles.create' USING ERRCODE = '42501';
  ELSIF op = 'update' AND NOT public.current_user_has_permission('roles.update') THEN
    RAISE EXCEPTION 'permission denied: roles.update' USING ERRCODE = '42501';
  ELSIF op = 'delete' AND NOT public.current_user_has_permission('roles.delete') THEN
    RAISE EXCEPTION 'permission denied: roles.delete' USING ERRCODE = '42501';
  ELSIF op NOT IN ('create', 'update', 'delete') THEN
    RAISE EXCEPTION 'unknown op: %', op USING ERRCODE = '22023';
  END IF;

  IF op IN ('create', 'update')
     AND permission_keys IS NOT NULL
     AND NOT public.current_user_has_permission('permissions.manage') THEN
    RAISE EXCEPTION 'permission denied: permissions.manage' USING ERRCODE = '42501';
  END IF;

  IF op IN ('update', 'delete') THEN
    PERFORM 1
    FROM public.roles r
    WHERE r.id = role_id
      AND r.updated_at = expected_updated_at
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'role concurrent edit' USING ERRCODE = '40001';
    END IF;
  END IF;

  IF op = 'update' AND permission_keys IS NOT NULL THEN
    SELECT COALESCE(array_agg(p.key ORDER BY p.key), ARRAY[]::TEXT[])
      INTO v_current_perms
    FROM public.role_permissions rp
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE rp.role_id = role_id;

    SELECT COALESCE(array_agg(k ORDER BY k), ARRAY[]::TEXT[])
      INTO v_requested_perms
    FROM unnest(permission_keys) AS k;

    IF (SELECT r.key FROM public.roles r WHERE r.id = role_id) = 'super_admin'
       AND v_current_perms IS DISTINCT FROM v_requested_perms THEN
      RAISE EXCEPTION 'super_admin permission set is immutable' USING ERRCODE = '42501';
    END IF;
  END IF;

  IF op = 'create' THEN
    IF role_key = 'super_admin' THEN
      RAISE EXCEPTION 'role key reserved: super_admin' USING ERRCODE = '23505';
    END IF;

    IF role_key IS NULL OR btrim(role_key) = '' THEN
      RAISE EXCEPTION 'role key is required' USING ERRCODE = '22023';
    END IF;

    IF display_name IS NULL
       OR (COALESCE(NULLIF(btrim(display_name->>'ar'), ''), NULLIF(btrim(display_name->>'en'), '')) IS NULL) THEN
      RAISE EXCEPTION 'display_name requires ar or en' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.roles (key, display_name, description, is_system)
    VALUES (role_key, display_name, description, FALSE)
    RETURNING id INTO v_role_id;

    INSERT INTO public.role_permissions (role_id, permission_id)
    SELECT v_role_id, p.id
    FROM public.permissions p
    WHERE p.key = ANY(COALESCE(permission_keys, ARRAY[]::TEXT[]))
    ON CONFLICT DO NOTHING;

  ELSIF op = 'update' THEN
    UPDATE public.roles r
    SET display_name = COALESCE(mutate_role.display_name, r.display_name),
        description = COALESCE(mutate_role.description, r.description)
    WHERE r.id = role_id
    RETURNING r.id INTO v_role_id;

    IF permission_keys IS NOT NULL THEN
      DELETE FROM public.role_permissions rp
      WHERE rp.role_id = role_id
        AND rp.permission_id NOT IN (
          SELECT p.id FROM public.permissions p WHERE p.key = ANY(permission_keys)
        );

      INSERT INTO public.role_permissions (role_id, permission_id)
      SELECT role_id, p.id
      FROM public.permissions p
      WHERE p.key = ANY(permission_keys)
        AND NOT EXISTS (
          SELECT 1
          FROM public.role_permissions rp2
          WHERE rp2.role_id = mutate_role.role_id
            AND rp2.permission_id = p.id
        )
      ON CONFLICT DO NOTHING;
    END IF;

  ELSIF op = 'delete' THEN
    SELECT r.key INTO v_role_key FROM public.roles r WHERE r.id = role_id;
    DELETE FROM public.roles r WHERE r.id = role_id;
    RETURN jsonb_build_object('role_id', role_id, 'key', v_role_key, 'deleted', TRUE);
  END IF;

  SELECT jsonb_build_object(
    'role_id', r.id,
    'key', r.key,
    'display_name', r.display_name,
    'description', r.description,
    'permission_keys', COALESCE((
      SELECT array_agg(p.key ORDER BY p.key)
      FROM public.role_permissions rp
      JOIN public.permissions p ON p.id = rp.permission_id
      WHERE rp.role_id = r.id
    ), ARRAY[]::TEXT[]),
    'updated_at', r.updated_at
  )
  INTO v_result
  FROM public.roles r
  WHERE r.id = v_role_id;

  RETURN v_result;
END;
$$;
