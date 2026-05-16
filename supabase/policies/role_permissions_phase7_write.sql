DROP POLICY IF EXISTS role_permissions_phase7_insert ON public.role_permissions;
CREATE POLICY role_permissions_phase7_insert ON public.role_permissions
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_permission('permissions.manage'));

DROP POLICY IF EXISTS role_permissions_phase7_delete ON public.role_permissions;
CREATE POLICY role_permissions_phase7_delete ON public.role_permissions
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('permissions.manage'));
