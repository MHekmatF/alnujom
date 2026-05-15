-- Phase 6: RLS policies for the `role_permissions` table.
-- Authenticated users can read all role-permission mappings (needed by PermissionChecker join).
-- No INSERT/UPDATE/DELETE policy in Phase 6 — mutations land in Phase 7.

DROP POLICY IF EXISTS role_permissions_read_all_authenticated ON public.role_permissions;
CREATE POLICY role_permissions_read_all_authenticated
  ON public.role_permissions
  FOR SELECT
  TO authenticated
  USING (TRUE);
