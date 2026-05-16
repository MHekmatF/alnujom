DROP POLICY IF EXISTS roles_phase7_insert ON public.roles;
CREATE POLICY roles_phase7_insert ON public.roles
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_permission('roles.create'));

DROP POLICY IF EXISTS roles_phase7_update ON public.roles;
CREATE POLICY roles_phase7_update ON public.roles
  FOR UPDATE TO authenticated
  USING (public.current_user_has_permission('roles.update'))
  WITH CHECK (public.current_user_has_permission('roles.update'));

DROP POLICY IF EXISTS roles_phase7_delete ON public.roles;
CREATE POLICY roles_phase7_delete ON public.roles
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('roles.delete'));
