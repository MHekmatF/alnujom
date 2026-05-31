-- Phase 19 (spec/019-agencies) — fix applied during the live backend apply (T074).
-- moderate_agency_internal had two bare `agency_id` column references (the
-- no_pending_verification EXISTS check and the verification-request UPDATE) that
-- collide with the RETURNS TABLE(agency_id ...) OUT parameter. With the Postgres
-- default plpgsql.variable_conflict = error, that raises SQLSTATE 42702
-- ("column reference agency_id is ambiguous") at RUNTIME on every approve/reject
-- (CREATE FUNCTION succeeds — plpgsql only catches it at first execution). This is
-- the same class as the Phase 18 fix_resolve_report_internal_listing_id_ambiguity
-- (memory project_supabase_view_rls_gotchas: "RETURNS TABLE OUT params collide with
-- same-named columns — alias tables"). Fix: alias agency_verification_requests AS avr
-- and qualify the two references. No behavior change otherwise. Idempotent (CREATE OR REPLACE).

CREATE OR REPLACE FUNCTION public.moderate_agency_internal(
  p_agency_id UUID, p_actor_user_id UUID, p_action TEXT, p_reason_json TEXT DEFAULT NULL
) RETURNS TABLE(agency_id UUID, status TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_cur agency_status; v_name TEXT; v_new agency_status;
BEGIN
  PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);

  IF p_action NOT IN ('approve','reject','suspend','reinstate') THEN
    RAISE EXCEPTION 'invalid_action' USING ERRCODE = '22023';
  END IF;

  SELECT a.status, a.name INTO v_cur, v_name FROM public.agencies a WHERE a.id = p_agency_id;
  IF v_cur IS NULL THEN RAISE EXCEPTION 'agency_not_found' USING ERRCODE = '23503'; END IF;

  IF p_action IN ('approve','reject')
     AND NOT EXISTS (SELECT 1 FROM public.agency_verification_requests avr
                     WHERE avr.agency_id = p_agency_id AND avr.decision = 'pending') THEN
    RAISE EXCEPTION 'no_pending_verification' USING ERRCODE = 'P0002';
  END IF;

  IF p_action = 'reject'
     AND COALESCE(NULLIF(trim(p_reason_json::jsonb->>'detail'),''), NULLIF(trim(p_reason_json::jsonb->>'preset'),'')) IS NULL THEN
    RAISE EXCEPTION 'rejection_reason_required' USING ERRCODE = '22023';
  END IF;

  IF p_action = 'approve' THEN
    IF v_cur <> 'pending' THEN RAISE EXCEPTION 'invalid_transition' USING ERRCODE='23514'; END IF;
    IF EXISTS (SELECT 1 FROM public.agencies a2
               WHERE lower(a2.name)=lower(v_name) AND a2.status='approved' AND a2.id <> p_agency_id) THEN
      RAISE EXCEPTION 'name_taken' USING ERRCODE='23505';
    END IF;
    v_new := 'approved';
  ELSIF p_action = 'reject' THEN
    IF v_cur <> 'pending' THEN RAISE EXCEPTION 'invalid_transition' USING ERRCODE='23514'; END IF;
    v_new := 'rejected';
  ELSIF p_action = 'suspend' THEN
    IF v_cur <> 'approved' THEN RAISE EXCEPTION 'invalid_transition' USING ERRCODE='23514'; END IF;
    v_new := 'suspended';
  ELSE  -- reinstate
    IF v_cur <> 'suspended' THEN RAISE EXCEPTION 'invalid_transition' USING ERRCODE='23514'; END IF;
    v_new := 'approved';
  END IF;

  UPDATE public.agencies SET status = v_new WHERE id = p_agency_id;

  IF p_action IN ('approve','reject') THEN
    UPDATE public.agency_verification_requests AS avr
       SET decision        = (CASE WHEN p_action='approve' THEN 'approved' ELSE 'rejected' END),
           decision_reason  = CASE WHEN p_action='reject'
                                   THEN COALESCE(NULLIF(trim(p_reason_json::jsonb->>'detail'),''),
                                                 NULLIF(trim(p_reason_json::jsonb->>'preset'),'')) END,
           reviewed_by      = p_actor_user_id,
           reviewed_at      = now()
     WHERE avr.agency_id = p_agency_id AND avr.decision = 'pending';
  END IF;

  RETURN QUERY SELECT p_agency_id, v_new::text;
END;
$$;

REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) TO service_role;
