-- Phase 6: Stacked cross-user SELECT policy on the existing `profiles` table.
-- Phase 4's profiles_policies.sql is NOT edited (R-05 / R-13 invariant preserved).
-- PostgreSQL ORs the USING clauses of multiple SELECT policies on the same table
-- for the same role — effective grant becomes "self OR users.view".

DROP POLICY IF EXISTS profiles_phase6_users_view ON public.profiles;
CREATE POLICY profiles_phase6_users_view
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('users.view'));
