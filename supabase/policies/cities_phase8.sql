-- Mirror of the inline RLS policies in supabase/migrations/20260517120002_create_cities.sql. R-02 dual-storage invariant.

-- SELECT: anon + authenticated (R-04 anonymous SELECT carve-out for global reference data)
DROP POLICY IF EXISTS cities_select_public ON public.cities;
CREATE POLICY cities_select_public
  ON public.cities
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT: requires locations.manage (Phase 6 §9.1 permission key)
DROP POLICY IF EXISTS cities_insert_locations_manage ON public.cities;
CREATE POLICY cities_insert_locations_manage
  ON public.cities
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- UPDATE: requires locations.manage
DROP POLICY IF EXISTS cities_update_locations_manage ON public.cities;
CREATE POLICY cities_update_locations_manage
  ON public.cities
  FOR UPDATE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'))
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- DELETE: requires locations.manage
DROP POLICY IF EXISTS cities_delete_locations_manage ON public.cities;
CREATE POLICY cities_delete_locations_manage
  ON public.cities
  FOR DELETE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'));
