-- Phase 6: Create current_user_has_permission(perm_key) helper function.
-- Also applies the user_roles_admin_cross_read policy which depends on this function
-- (policy was deferred from migration 4 because the function did not exist yet).
-- Contract: contracts/permission-predicate.md
-- FR-008

CREATE OR REPLACE FUNCTION public.current_user_has_permission(perm_key TEXT)
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
      JOIN public.role_permissions rp ON rp.role_id = ur.role_id
      JOIN public.permissions p ON p.id = rp.permission_id
      WHERE ur.user_id = auth.uid()
        AND p.key = perm_key
    )
  ), FALSE);
$$;

-- generated from supabase/policies/user_roles_policies.sql (admin cross-read)
-- Deferred from migration 4 — current_user_has_permission must exist first.
DROP POLICY IF EXISTS user_roles_admin_cross_read ON public.user_roles;
CREATE POLICY user_roles_admin_cross_read
  ON public.user_roles
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('users.view'));
