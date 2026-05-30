-- Phase 19 (spec/019-agencies) — Sub-Phase D, migration 8/13.
-- Agency write RPCs (data-model §1.8 / contracts/phase19-agency-write-rpcs.md). The
-- ONLY creation/membership/verification write paths: each SECURITY DEFINER + self-gating
-- (auth.uid() binding / is_agency_admin / invitee-only), every grant to authenticated.
-- The three agency tables carry NO client INSERT/UPDATE/DELETE grant (20260531120005),
-- so these RPCs are bypass-proof. References app_vault_set_agency_secret (…007).

-- create_agency — one agency per approved publisher (Q3=A / R-138). Seeds owner as admin/active member.
CREATE OR REPLACE FUNCTION public.create_agency(
  p_name TEXT, p_description TEXT DEFAULT NULL, p_phone TEXT DEFAULT NULL,
  p_whatsapp TEXT DEFAULT NULL, p_address TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_uid UUID := auth.uid(); v_id UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles p
                 WHERE p.user_id = v_uid AND p.publisher_status='approved' AND p.account_status='approved') THEN
    RAISE EXCEPTION 'not_a_publisher' USING ERRCODE = '42501';
  END IF;
  IF EXISTS (SELECT 1 FROM public.agencies a WHERE a.owner_user_id = v_uid) THEN
    RAISE EXCEPTION 'already_owns_agency' USING ERRCODE = '23505';
  END IF;
  IF p_name IS NULL OR length(trim(p_name)) = 0 THEN
    RAISE EXCEPTION 'invalid_name' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.agencies (owner_user_id, name, description, phone, whatsapp, address, status)
  VALUES (v_uid, trim(p_name), p_description, p_phone, p_whatsapp, p_address, 'pending')
  RETURNING id INTO v_id;
  INSERT INTO public.agency_members (agency_id, user_id, member_role, status, joined_at)
  VALUES (v_id, v_uid, 'admin', 'active', now());
  RETURN v_id;
END;
$$;

-- invite_agency_member — agency-admin invites an EXISTING account by phone (Q2=B / R-139).
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
  RETURN v_target;
END;
$$;

-- respond_agency_invitation — INVITEE only (bound to auth.uid()).
CREATE OR REPLACE FUNCTION public.respond_agency_invitation(p_agency_id UUID, p_accept BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE public.agency_members
     SET status = CASE WHEN p_accept THEN 'active' ELSE 'removed' END,
         joined_at = CASE WHEN p_accept THEN now() ELSE joined_at END
   WHERE agency_id = p_agency_id AND user_id = auth.uid() AND status = 'pending';
  IF NOT FOUND THEN RAISE EXCEPTION 'no_pending_invitation' USING ERRCODE='P0002'; END IF;
END;
$$;

-- set_agency_member_role / remove_agency_member — agency-admin only; the owner is protected.
CREATE OR REPLACE FUNCTION public.set_agency_member_role(p_agency_id UUID, p_user_id UUID, p_role TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_agency_admin(p_agency_id) THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
  IF p_role NOT IN ('admin','agent') THEN RAISE EXCEPTION 'invalid_role' USING ERRCODE='22023'; END IF;
  IF EXISTS (SELECT 1 FROM public.agencies a WHERE a.id=p_agency_id AND a.owner_user_id=p_user_id) THEN
    RAISE EXCEPTION 'cannot_modify_owner' USING ERRCODE='42501';
  END IF;
  UPDATE public.agency_members SET member_role=p_role
   WHERE agency_id=p_agency_id AND user_id=p_user_id AND status='active';
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_agency_member(p_agency_id UUID, p_user_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_agency_admin(p_agency_id) THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
  IF EXISTS (SELECT 1 FROM public.agencies a WHERE a.id=p_agency_id AND a.owner_user_id=p_user_id) THEN
    RAISE EXCEPTION 'cannot_remove_owner' USING ERRCODE='42501';
  END IF;
  UPDATE public.agency_members SET status='removed' WHERE agency_id=p_agency_id AND user_id=p_user_id;
END;
$$;

-- submit_agency_verification — agency-admin; inserts request + stores Vault PII (R-141).
CREATE OR REPLACE FUNCTION public.submit_agency_verification(
  p_agency_id UUID, p_id_document_number TEXT, p_registration_number TEXT, p_evidence_urls JSONB DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id UUID;
BEGIN
  IF NOT public.is_agency_admin(p_agency_id) THEN RAISE EXCEPTION 'permission_denied' USING ERRCODE='42501'; END IF;
  INSERT INTO public.agency_verification_requests (agency_id, evidence_urls, submitted_by, decision)
  VALUES (p_agency_id, p_evidence_urls, auth.uid(), 'pending')          -- ux_agency_open_verification ⇒ 23505 if one is open
  RETURNING id INTO v_id;
  IF p_id_document_number IS NOT NULL THEN
    PERFORM public.app_vault_set_agency_secret(p_agency_id, 'id_document_number', p_id_document_number);
  END IF;
  IF p_registration_number IS NOT NULL THEN
    PERFORM public.app_vault_set_agency_secret(p_agency_id, 'commercial_registration_number', p_registration_number);
  END IF;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_agency(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_agency(TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.invite_agency_member(UUID,TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.invite_agency_member(UUID,TEXT,TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.respond_agency_invitation(UUID,BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_agency_invitation(UUID,BOOLEAN) TO authenticated;
REVOKE ALL ON FUNCTION public.set_agency_member_role(UUID,UUID,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_agency_member_role(UUID,UUID,TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.remove_agency_member(UUID,UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.remove_agency_member(UUID,UUID) TO authenticated;
REVOKE ALL ON FUNCTION public.submit_agency_verification(UUID,TEXT,TEXT,JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_agency_verification(UUID,TEXT,TEXT,JSONB) TO authenticated;
