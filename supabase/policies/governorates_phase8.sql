-- Mirror of the inline RLS policies in supabase/migrations/20260517120001_create_governorates.sql. R-02 dual-storage invariant.

-- SELECT: anon + authenticated (R-04 anonymous SELECT carve-out for global reference data)
DROP POLICY IF EXISTS governorates_select_public ON public.governorates;
CREATE POLICY governorates_select_public
  ON public.governorates
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT: requires locations.manage (Phase 6 §9.1 permission key)
DROP POLICY IF EXISTS governorates_insert_locations_manage ON public.governorates;
CREATE POLICY governorates_insert_locations_manage
  ON public.governorates
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- UPDATE: requires locations.manage
DROP POLICY IF EXISTS governorates_update_locations_manage ON public.governorates;
CREATE POLICY governorates_update_locations_manage
  ON public.governorates
  FOR UPDATE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'))
  WITH CHECK (public.current_user_has_permission('locations.manage'));

-- DELETE: requires locations.manage
DROP POLICY IF EXISTS governorates_delete_locations_manage ON public.governorates;
CREATE POLICY governorates_delete_locations_manage
  ON public.governorates
  FOR DELETE
  TO authenticated
  USING (public.current_user_has_permission('locations.manage'));
