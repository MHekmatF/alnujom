-- Phase 19 (spec/019-agencies) — Migration 10/13.
-- moderate_agency_internal — service-role-only atomic agency-moderation state machine
-- (FR-008/FR-010/FR-039). Mirrors the Phase 12 approve_reject_atomic_wrappers
-- (20260523120005): sets app.current_user_id so trg_agencies_audit_status +
-- trg_agency_verification_audit attribute the actor; transitions the agency + the open
-- verification request in ONE transaction. This is the SECOND enforcement layer behind
-- the moderate_agency Edge Function (SC-011) — it is never client-callable.
--
-- Action → transition (data-model §1.10 / contracts/phase19-moderate-agency-edge-function.md):
--   approve   : pending   → approved   (+ name free among approved); request → approved
--   reject    : pending   → rejected   (reason required);            request → rejected
--   suspend   : approved  → suspended
--   reinstate : suspended → approved
-- References: data-model.md §1.10; research.md R-145 (name-collision on approve), R-149.

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

  -- approve/reject act on a pending verification request (the queue only surfaces those).
  IF p_action IN ('approve','reject')
     AND NOT EXISTS (SELECT 1 FROM public.agency_verification_requests
                     WHERE agency_id = p_agency_id AND decision = 'pending') THEN
    RAISE EXCEPTION 'no_pending_verification' USING ERRCODE = 'P0002';
  END IF;

  -- A reject MUST carry a reason (the agency_verification_reason_when_rejected CHECK requires it).
  IF p_action = 'reject'
     AND COALESCE(NULLIF(trim(p_reason_json::jsonb->>'detail'),''), NULLIF(trim(p_reason_json::jsonb->>'preset'),'')) IS NULL THEN
    RAISE EXCEPTION 'rejection_reason_required' USING ERRCODE = '22023';   -- trim() so a whitespace-only reason is a clean 400, not a CHECK-violation 500
  END IF;

  IF p_action = 'approve' THEN
    IF v_cur <> 'pending' THEN RAISE EXCEPTION 'invalid_transition' USING ERRCODE='23514'; END IF;
    IF EXISTS (SELECT 1 FROM public.agencies a2
               WHERE lower(a2.name)=lower(v_name) AND a2.status='approved' AND a2.id <> p_agency_id) THEN
      RAISE EXCEPTION 'name_taken' USING ERRCODE='23505';                     -- R-145 / FR-008
    END IF;
    -- Concurrent backstop: if two approvals of the same name race past this check,
    -- ux_agencies_name_approved raises 23505 on the second commit; the Edge Function maps
    -- either 23505 to name_taken/409 (one approval wins, the other gets name_taken).
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

  UPDATE public.agencies SET status = v_new WHERE id = p_agency_id;          -- fires trg_agencies_audit_status

  IF p_action IN ('approve','reject') THEN
    UPDATE public.agency_verification_requests
       SET decision        = (CASE WHEN p_action='approve' THEN 'approved' ELSE 'rejected' END),
           decision_reason  = CASE WHEN p_action='reject'
                                   THEN COALESCE(NULLIF(trim(p_reason_json::jsonb->>'detail'),''),
                                                 NULLIF(trim(p_reason_json::jsonb->>'preset'),'')) END,
           reviewed_by      = p_actor_user_id,
           reviewed_at      = now()
     WHERE agency_id = p_agency_id AND decision = 'pending';                 -- fires trg_agency_verification_audit
  END IF;

  RETURN QUERY SELECT p_agency_id, v_new::text;
END;
$$;

REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_agency_internal(UUID,UUID,TEXT,TEXT) TO service_role;
