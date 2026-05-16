-- Phase 7: Write-side RLS policies for the Phase 6 role/permission catalog.
-- Source: specs/007-super-admin-roles/contracts/phase7-write-policies.md
-- FR-004, FR-005, FR-006, FR-007. Parallel policy files live under supabase/policies/.

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

DROP POLICY IF EXISTS role_permissions_phase7_insert ON public.role_permissions;
CREATE POLICY role_permissions_phase7_insert ON public.role_permissions
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_permission('permissions.manage'));

DROP POLICY IF EXISTS role_permissions_phase7_delete ON public.role_permissions;
CREATE POLICY role_permissions_phase7_delete ON public.role_permissions
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('permissions.manage'));

DROP POLICY IF EXISTS user_roles_phase7_insert ON public.user_roles;
CREATE POLICY user_roles_phase7_insert ON public.user_roles
  FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_permission('permissions.manage'));

DROP POLICY IF EXISTS user_roles_phase7_delete ON public.user_roles;
CREATE POLICY user_roles_phase7_delete ON public.user_roles
  FOR DELETE TO authenticated
  USING (public.current_user_has_permission('permissions.manage'));
