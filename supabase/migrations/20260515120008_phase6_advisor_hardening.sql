-- Phase 6: Defense-in-depth — revoke public/anon execute on SECURITY DEFINER functions,
-- grant only to authenticated for the user-callable helpers.
-- Mirrors Phase 5's 20260510120006_phase5_advisor_hardening.sql pattern.
-- Constitution III (NON-NEGOTIABLE).

-- Revoke from PUBLIC and anon: prevents unauthenticated callers from invoking
-- permission/role helpers and leaking membership information.
REVOKE EXECUTE ON FUNCTION public.current_user_has_permission(TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.current_user_is_admin() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.auto_create_user_role_for_user() FROM PUBLIC, anon;

-- Grant to authenticated: the two user-callable helpers are invoked by RLS policies
-- and by Flutter-side Postgrest calls for authenticated sessions.
GRANT EXECUTE ON FUNCTION public.current_user_has_permission(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin() TO authenticated;

-- auto_create_user_role_for_user is trigger-only; no explicit grant to authenticated
-- needed — SECURITY DEFINER runs as the function owner regardless of caller privileges.

-- Harden enforce_role_system_immutability: add explicit search_path (triggered by advisor).
CREATE OR REPLACE FUNCTION public.enforce_role_system_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
AS $$
BEGIN
  IF (TG_OP = 'DELETE' AND OLD.is_system) THEN
    RAISE EXCEPTION 'cannot delete system role: %', OLD.key
      USING ERRCODE = '42501';
  END IF;

  IF (TG_OP = 'UPDATE' AND OLD.is_system AND NEW.key IS DISTINCT FROM OLD.key) THEN
    RAISE EXCEPTION 'cannot rename system role: % (attempted new key: %)', OLD.key, NEW.key
      USING ERRCODE = '42501';
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;
