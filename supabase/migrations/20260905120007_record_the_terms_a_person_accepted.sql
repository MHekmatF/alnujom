-- Record the terms a person accepted.
--
-- Review 2026-09-05 §4 G1 (plan A27). There was no terms-of-service document
-- and no acceptance step, so nothing told a user what is not allowed and
-- nothing recorded that they agreed — which weakens every enforcement action
-- A29 made possible. The document now exists (docs/legal/terms-of-service.md,
-- bundled in the app and published beside the privacy policy); this records
-- the acceptance.
--
-- Two columns on the profile, written only by `accept_terms(version)` as the
-- signed-in user — called by the app right after a successful registration,
-- and again whenever a new version is accepted. The version is the document's
-- date, so a later terms change can ask again by comparing strings.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS terms_accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS terms_version text;

CREATE OR REPLACE FUNCTION public.accept_terms(p_version text)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_at timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_version IS NULL OR p_version !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
    RAISE EXCEPTION 'invalid_version' USING ERRCODE = '22023';
  END IF;
  UPDATE public.profiles
     SET terms_accepted_at = now(), terms_version = p_version
   WHERE user_id = auth.uid()
  RETURNING terms_accepted_at INTO v_at;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0002';
  END IF;
  RETURN v_at;
END;
$function$;

REVOKE ALL ON FUNCTION public.accept_terms(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_terms(text) TO authenticated;
COMMENT ON FUNCTION public.accept_terms(text) IS
  'Records that the signed-in user accepted the terms of service at this version (the document date). Called by the app after registration (plan A27).';
COMMENT ON COLUMN public.profiles.terms_accepted_at IS 'When the person last accepted the terms of service (plan A27).';
COMMENT ON COLUMN public.profiles.terms_version IS 'Which terms version (document date) they accepted (plan A27).';

NOTIFY pgrst, 'reload schema';
