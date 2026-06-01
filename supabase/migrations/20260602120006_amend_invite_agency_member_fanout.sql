-- Phase 22 (spec/022-notifications-realtime) — Migration 6/11.
-- Re-based CREATE-OR-REPLACE amendment (R-183) of the Phase 19 invite_agency_member RPC
-- (base 20260531120008). Additive ONLY: every existing line of THIS function preserved
-- verbatim (signature, search_path, admin gate, role check, target resolution, idempotent
-- INSERT … ON CONFLICT DO NOTHING). Inserts exactly ONE PERFORM
-- public.enqueue_notification(...) addressed to the resolved invitee v_target after the
-- agency_members INSERT. The OTHER agency RPCs in 20260531120008 are NOT re-created here
-- (no edit to them). Grants for invite_agency_member re-asserted unchanged.
-- Idempotent: create-or-replace + re-asserted grants; safely re-runnable.

CREATE OR REPLACE FUNCTION public.invite_agency_member(
  p_agency_id UUID, p_phone TEXT, p_role TEXT DEFAULT 'agent'
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_target UUID;
BEGIN
  IF NOT public.is_agency_admin(p_agency_id) THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
  IF p_role NOT IN ('admin','agent') THEN RAISE EXCEPTION 'invalid_role' USING ERRCODE='22023'; END IF;
  SELECT user_id INTO v_target FROM public.profiles WHERE phone = p_phone;     -- caller passes E.164-normalized phone
  IF v_target IS NULL THEN RAISE EXCEPTION 'user_not_found' USING ERRCODE='23503'; END IF;
  INSERT INTO public.agency_members (agency_id, user_id, member_role, status, invited_by)
  VALUES (p_agency_id, v_target, p_role, 'pending', auth.uid())
  ON CONFLICT (agency_id, user_id) DO NOTHING;                                 -- idempotent (already member/invited)

  -- Phase 22 fan-out: notify the resolved invitee (server-resolved recipient — FR-002);
  -- params carry the agency_id for the /agency deep link (FR-004). v_target already in scope.
  PERFORM public.enqueue_notification(
    v_target, 'agency_invitation', jsonb_build_object('agency_id', p_agency_id));

  RETURN v_target;
END;
$$;

REVOKE ALL ON FUNCTION public.invite_agency_member(UUID,TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.invite_agency_member(UUID,TEXT,TEXT) TO authenticated;
