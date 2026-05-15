-- Phase 6 patch: add SET search_path to enforce_profile_status_admin_only.
-- Resolves advisor lint function_search_path_mutable introduced when migration 7 rewrote
-- the function body without the hardening that migration 8 applied to other Phase 6 functions.
CREATE OR REPLACE FUNCTION public.enforce_profile_status_admin_only()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, auth
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
