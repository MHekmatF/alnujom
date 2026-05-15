-- Phase 6: RLS policies for the `roles` table.
-- Authenticated users can read the full role catalog.
-- No INSERT/UPDATE/DELETE policy in Phase 6 — mutations land in Phase 7.

DROP POLICY IF EXISTS roles_read_all_authenticated ON public.roles;
CREATE POLICY roles_read_all_authenticated
  ON public.roles
  FOR SELECT
  TO authenticated
  USING (TRUE);
