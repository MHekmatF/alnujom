-- Phase 6: RLS policies for the `permissions` table.
-- Authenticated users can read the full permission catalog.
-- No INSERT/UPDATE/DELETE policy in Phase 6 — permissions are immutable in v1.

DROP POLICY IF EXISTS permissions_read_all_authenticated ON public.permissions;
CREATE POLICY permissions_read_all_authenticated
  ON public.permissions
  FOR SELECT
  TO authenticated
  USING (TRUE);
