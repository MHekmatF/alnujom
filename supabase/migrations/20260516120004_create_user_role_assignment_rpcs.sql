-- Phase 7: SECURITY DEFINER user-role assignment RPCs.
-- Source: specs/007-super-admin-roles/contracts/assign-role-to-user-rpc.md
--         specs/007-super-admin-roles/contracts/revoke-role-from-user-rpc.md
-- FR-009. Encodes Clarifications Q1 (two-step super_admin grant confirmation)
-- and Q2 (unconditional super_admin self-revoke block).

CREATE OR REPLACE FUNCTION public.assign_role_to_user(
  target_user_id     UUID,
  target_role_id     UUID,
  confirmation_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_super_admin_id UUID;
  v_target_phone TEXT;
  v_target_username TEXT;
  v_granted_at TIMESTAMPTZ := now();
BEGIN
  IF NOT public.current_user_has_permission('permissions.manage') THEN
    RAISE EXCEPTION 'permission denied: permissions.manage' USING ERRCODE = '42501';
  END IF;

  SELECT id INTO v_super_admin_id FROM public.roles WHERE key = 'super_admin';

  IF target_role_id = v_super_admin_id THEN
    IF confirmation_token IS NULL THEN
      RAISE EXCEPTION 'super_admin grant requires confirmation_token' USING ERRCODE = '42501';
    END IF;

    SELECT p.phone, p.username
      INTO v_target_phone, v_target_username
    FROM public.profiles p
    WHERE p.user_id = target_user_id;

    IF confirmation_token IS DISTINCT FROM v_target_phone
       AND confirmation_token IS DISTINCT FROM v_target_username THEN
      RAISE EXCEPTION 'super_admin grant confirmation failed' USING ERRCODE = '42501';
    END IF;
  END IF;

  INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
  VALUES (target_user_id, target_role_id, auth.uid(), v_granted_at);

  RETURN jsonb_build_object(
    'user_id', target_user_id,
    'role_id', target_role_id,
    'granted_by', auth.uid(),
    'granted_at', v_granted_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_role_from_user(
  target_user_id UUID,
  target_role_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_super_admin_id UUID;
  v_rows_affected INTEGER;
  v_revoked_at TIMESTAMPTZ := now();
BEGIN
  IF NOT public.current_user_has_permission('permissions.manage') THEN
    RAISE EXCEPTION 'permission denied: permissions.manage' USING ERRCODE = '42501';
  END IF;

  SELECT id INTO v_super_admin_id FROM public.roles WHERE key = 'super_admin';

  IF target_role_id = v_super_admin_id AND auth.uid() = target_user_id THEN
    RAISE EXCEPTION 'super_admin self-revoke forbidden' USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.user_roles ur
  WHERE ur.user_id = target_user_id
    AND ur.role_id = target_role_id;

  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

  IF v_rows_affected = 0 THEN
    RAISE EXCEPTION 'user does not hold role' USING ERRCODE = '02000';
  END IF;

  RETURN jsonb_build_object(
    'user_id', target_user_id,
    'role_id', target_role_id,
    'revoked_by', auth.uid(),
    'revoked_at', v_revoked_at
  );
END;
$$;
