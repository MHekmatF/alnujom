-- Phase 19 (spec 019-agencies) — Wave 3 review follow-up (the FR-002 editable-profile write path).
-- public.agencies has no client UPDATE grant (REVOKE'd in 20260531120005), so the
-- owner / agency-admin edits the agency profile through this SECURITY DEFINER RPC,
-- gated by is_agency_admin(p_agency_id) — never a direct client UPDATE.
-- PATCH semantics: omitted/NULL params leave the column unchanged (the datasource
-- omits null fields). Editable only while the agency is 'pending' or 'approved' (FR-002).
-- (The data-model.md §1.8 RPC set originally omitted this; added here to close the gap
-- between the AgencyRepository.updateProfile path and the backend.)

CREATE OR REPLACE FUNCTION public.update_agency_profile(
  p_agency_id   UUID,
  p_name        TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_phone       TEXT DEFAULT NULL,
  p_whatsapp    TEXT DEFAULT NULL,
  p_address     TEXT DEFAULT NULL,
  p_logo_path   TEXT DEFAULT NULL,
  p_cover_path  TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_agency_admin(p_agency_id) THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;

  IF p_name IS NOT NULL AND length(trim(p_name)) = 0 THEN
    RAISE EXCEPTION 'invalid_name' USING ERRCODE = '22023';
  END IF;

  UPDATE public.agencies
     SET name        = COALESCE(NULLIF(trim(p_name), ''), name),
         description = COALESCE(p_description, description),
         phone       = COALESCE(p_phone, phone),
         whatsapp    = COALESCE(p_whatsapp, whatsapp),
         address     = COALESCE(p_address, address),
         logo_path   = COALESCE(p_logo_path, logo_path),
         cover_path  = COALESCE(p_cover_path, cover_path)
   WHERE id = p_agency_id
     AND status IN ('pending', 'approved');     -- not editable while rejected/suspended
  -- A rename to a name already held by another APPROVED agency is rejected by the
  -- ux_agencies_name_approved partial unique index (23505) — surfaced as a failure.

  IF NOT FOUND THEN
    RAISE EXCEPTION 'agency_not_editable' USING ERRCODE = '42501';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_agency_profile(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_agency_profile(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
