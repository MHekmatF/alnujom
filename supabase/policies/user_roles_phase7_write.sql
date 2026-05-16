DROP POLICY IF EXISTS user_roles_phase7_insert ON public.user_roles;
CREATE POLICY user_roles_phase7_insert ON public.user_roles
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_permission('permissions.manage'));

DROP POLICY IF EXISTS user_roles_phase7_delete ON public.user_roles;
CREATE POLICY user_roles_phase7_delete ON public.user_roles
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('permissions.manage'));
