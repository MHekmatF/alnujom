-- Phase 6: Create the `user_roles` table with audit triggers and auto-user-role trigger.
-- Contracts: contracts/user-roles-table.md, contracts/auto-user-role-trigger.md,
--            contracts/user-roles-audit-trigger.md
-- FR-007, FR-010, FR-013, R-14, R-15

CREATE TABLE IF NOT EXISTS public.user_roles (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES auth.users(id)     ON DELETE CASCADE,
  role_id    UUID        NOT NULL REFERENCES public.roles(id)   ON DELETE RESTRICT,
  granted_by UUID        REFERENCES auth.users(id)              ON DELETE SET NULL,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, role_id)
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- generated from supabase/policies/user_roles_policies.sql
DROP POLICY IF EXISTS user_roles_self_read ON public.user_roles;
CREATE POLICY user_roles_self_read
  ON public.user_roles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Note: user_roles_admin_cross_read depends on current_user_has_permission (migration 5).
-- It is applied in migration 5 after the helper function exists.

-- Auto-user-role trigger: every new profiles row gets the default 'user' role.
-- SECURITY DEFINER because auth.uid() (the new user) has no INSERT permission on user_roles.
CREATE OR REPLACE FUNCTION public.auto_create_user_role_for_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  INSERT INTO public.user_roles (user_id, role_id, granted_by, granted_at)
  VALUES (NEW.user_id, (SELECT id FROM public.roles WHERE key = 'user'), NULL, now())
  ON CONFLICT (user_id, role_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_auto_user_role ON public.profiles;
CREATE TRIGGER trg_profiles_auto_user_role
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.auto_create_user_role_for_user();

-- Audit triggers: two separate triggers per Phase 5 convention (log_audit takes
-- the action string verbatim from TG_ARGV[0] — no TG_OP-derived verb appended).
DROP TRIGGER IF EXISTS trg_user_roles_audit_granted ON public.user_roles;
CREATE TRIGGER trg_user_roles_audit_granted
  AFTER INSERT ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('user_role.granted', '*', 'user_id');

DROP TRIGGER IF EXISTS trg_user_roles_audit_revoked ON public.user_roles;
CREATE TRIGGER trg_user_roles_audit_revoked
  AFTER DELETE ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('user_role.revoked', '*', 'user_id');
