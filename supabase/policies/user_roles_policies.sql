-- Phase 6: RLS policies for the `user_roles` table.
-- Self-read: a user can read their own role assignments (used by profile page).
-- Admin cross-read: users with users.view permission can read any user's roles.
-- No INSERT/UPDATE/DELETE policy in Phase 6 — mutations land in Phase 7.
-- The FR-011 backfill runs as postgres and bypasses RLS for its INSERTs.

DROP POLICY IF EXISTS user_roles_self_read ON public.user_roles;
CREATE POLICY user_roles_self_read
  ON public.user_roles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_roles_admin_cross_read ON public.user_roles;
CREATE POLICY user_roles_admin_cross_read
  ON public.user_roles
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('users.view'));
