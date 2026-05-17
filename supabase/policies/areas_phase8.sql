-- Mirror of the inline RLS policies in supabase/migrations/20260517120003_create_areas.sql. R-02 dual-storage invariant.

-- SELECT: anon + authenticated (R-04 anonymous SELECT carve-out for global reference data)
DROP POLICY IF EXISTS areas_select_public ON public.areas;
CREATE POLICY areas_select_public
  ON public.areas
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT: requires locations.manage (Phase 6 §9.1 permission key)
DROP POLICY IF EXISTS areas_insert_locations_manage ON public.areas;
CREATE POLICY areas_insert_locations_manage
  ON public.areas
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- UPDATE: requires locations.manage
DROP POLICY IF EXISTS areas_update_locations_manage ON public.areas;
CREATE POLICY areas_update_locations_manage
  ON public.areas
  FOR UPDATE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'))
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- DELETE: requires locations.manage
DROP POLICY IF EXISTS areas_delete_locations_manage ON public.areas;
CREATE POLICY areas_delete_locations_manage
  ON public.areas
  FOR DELETE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'));
