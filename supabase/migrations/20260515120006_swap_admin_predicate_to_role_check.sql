-- Phase 6: Swap current_user_is_admin() body to a role-membership check.
-- Also bundles the new stacked cross-user profiles read policy.
-- Contracts: contracts/admin-predicate-v6.md, contracts/profiles-users-view-policy.md
-- FR-012, R-12, R-05 (no Phase 4/5 policy files edited)
--
-- ⚠ HAZARDOUS INTERMEDIATE STATE after this migration applies:
-- current_user_is_admin() returns FALSE for every user until the backfill
-- migration (20260515120007) runs and assigns admin/user roles.
-- Apply migrations 6 → 7 without pause.

CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT COALESCE((
    EXISTS (
      SELECT 1
      FROM public.user_roles ur
      JOIN public.roles r ON r.id = ur.role_id
      WHERE ur.user_id = auth.uid()
        AND r.key IN ('admin', 'super_admin')
    )
  ), FALSE);
$$;

-- generated from supabase/policies/profiles_phase6_users_view.sql
-- Stacked on top of Phase 4's self-only policy; profiles_policies.sql is NOT edited (R-05).
DROP POLICY IF EXISTS profiles_phase6_users_view ON public.profiles;
CREATE POLICY profiles_phase6_users_view
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('users.view'));
