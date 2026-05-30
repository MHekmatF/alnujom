-- Phase 19 (spec/019-agencies) — Migration 12/13 — advisor hardening (T029).
-- Matches the Phase 16/17/18 advisor-hardening files
-- (20260527120012 / 20260529120005 / 20260530120008).
--
-- Safety-net ALTER FUNCTION … SET search_path for ALL Phase-19 functions +
-- re-assert grants + re-assert the 3-table write-lockdown REVOKEs +
-- GRANT SELECT ON public.v_agencies TO anon, authenticated.
--
-- APPLY-ORDER NOTE: every Phase-19 function-creating migration (…120001–…120011)
-- sorts BEFORE this file (…120012), so under in-order migration apply they always
-- exist by the time this runs. Each ALTER/grant is nevertheless wrapped in an
-- EXISTS guard (by function arg-signature, or by relation/view name) so this
-- hardening file is forward-safe even if a given environment has not yet landed
-- a particular predecessor — it then no-ops rather than erroring. Idempotent.

-- ───────────────────────────────────────────────────────────────────────────
-- 1. search_path hardening + re-assert grants for the functions that GRANT to
--    authenticated (the 2 membership predicates, the 2 Vault helpers, the 6
--    write RPCs, and the amended submit_listing).
-- ───────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  -- Membership predicates (20260531120002).
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.is_agency_member(uuid)'::regprocedure) THEN
    ALTER FUNCTION public.is_agency_member(UUID) SET search_path = public;
    REVOKE ALL ON FUNCTION public.is_agency_member(UUID) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.is_agency_member(UUID) TO authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.is_agency_admin(uuid)'::regprocedure) THEN
    ALTER FUNCTION public.is_agency_admin(UUID) SET search_path = public;
    REVOKE ALL ON FUNCTION public.is_agency_admin(UUID) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.is_agency_admin(UUID) TO authenticated;
  END IF;

  -- Vault helpers (20260531120007).
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.app_vault_set_agency_secret(uuid,text,text)'::regprocedure) THEN
    ALTER FUNCTION public.app_vault_set_agency_secret(UUID, TEXT, TEXT) SET search_path = public, vault;
    REVOKE ALL ON FUNCTION public.app_vault_set_agency_secret(UUID, TEXT, TEXT) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.app_vault_set_agency_secret(UUID, TEXT, TEXT) TO authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.app_vault_secret_for_agency(uuid,text)'::regprocedure) THEN
    ALTER FUNCTION public.app_vault_secret_for_agency(UUID, TEXT) SET search_path = public;
    REVOKE ALL ON FUNCTION public.app_vault_secret_for_agency(UUID, TEXT) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.app_vault_secret_for_agency(UUID, TEXT) TO authenticated;
  END IF;

  -- Write RPCs (20260531120008).
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.create_agency(text,text,text,text,text)'::regprocedure) THEN
    ALTER FUNCTION public.create_agency(TEXT, TEXT, TEXT, TEXT, TEXT) SET search_path = public, pg_temp;
    REVOKE ALL ON FUNCTION public.create_agency(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.create_agency(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.invite_agency_member(uuid,text,text)'::regprocedure) THEN
    ALTER FUNCTION public.invite_agency_member(UUID, TEXT, TEXT) SET search_path = public, pg_temp;
    REVOKE ALL ON FUNCTION public.invite_agency_member(UUID, TEXT, TEXT) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.invite_agency_member(UUID, TEXT, TEXT) TO authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.respond_agency_invitation(uuid,boolean)'::regprocedure) THEN
    ALTER FUNCTION public.respond_agency_invitation(UUID, BOOLEAN) SET search_path = public, pg_temp;
    REVOKE ALL ON FUNCTION public.respond_agency_invitation(UUID, BOOLEAN) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.respond_agency_invitation(UUID, BOOLEAN) TO authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.set_agency_member_role(uuid,uuid,text)'::regprocedure) THEN
    ALTER FUNCTION public.set_agency_member_role(UUID, UUID, TEXT) SET search_path = public, pg_temp;
    REVOKE ALL ON FUNCTION public.set_agency_member_role(UUID, UUID, TEXT) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.set_agency_member_role(UUID, UUID, TEXT) TO authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.remove_agency_member(uuid,uuid)'::regprocedure) THEN
    ALTER FUNCTION public.remove_agency_member(UUID, UUID) SET search_path = public, pg_temp;
    REVOKE ALL ON FUNCTION public.remove_agency_member(UUID, UUID) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.remove_agency_member(UUID, UUID) TO authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.submit_agency_verification(uuid,text,text,jsonb)'::regprocedure) THEN
    ALTER FUNCTION public.submit_agency_verification(UUID, TEXT, TEXT, JSONB) SET search_path = public, pg_temp;
    REVOKE ALL ON FUNCTION public.submit_agency_verification(UUID, TEXT, TEXT, JSONB) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.submit_agency_verification(UUID, TEXT, TEXT, JSONB) TO authenticated;
  END IF;

  -- Amended submit_listing (20260531120009) — keep its existing authenticated grant.
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.submit_listing(uuid)'::regprocedure) THEN
    ALTER FUNCTION public.submit_listing(UUID) SET search_path = public, auth;
    REVOKE ALL ON FUNCTION public.submit_listing(UUID) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.submit_listing(UUID) TO authenticated;
  END IF;

  -- Service-role-only moderation RPC (20260531120010).
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.moderate_agency_internal(uuid,uuid,text,text)'::regprocedure) THEN
    ALTER FUNCTION public.moderate_agency_internal(UUID, UUID, TEXT, TEXT) SET search_path = public, pg_temp;
    REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID, UUID, TEXT, TEXT) FROM PUBLIC;
    REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID, UUID, TEXT, TEXT) FROM anon;
    REVOKE ALL ON FUNCTION public.moderate_agency_internal(UUID, UUID, TEXT, TEXT) FROM authenticated;
    GRANT EXECUTE ON FUNCTION public.moderate_agency_internal(UUID, UUID, TEXT, TEXT) TO service_role;
  END IF;
END
$$;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. Re-assert table write-lockdown (RPC-only writes; no client mutation) on the
--    3 Phase-19 tables (guarded so each no-ops if its table is not yet present).
-- ───────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF to_regclass('public.agencies') IS NOT NULL THEN
    REVOKE INSERT, UPDATE, DELETE ON public.agencies FROM authenticated, anon;
  END IF;
  IF to_regclass('public.agency_members') IS NOT NULL THEN
    REVOKE INSERT, UPDATE, DELETE ON public.agency_members FROM authenticated, anon;
  END IF;
  IF to_regclass('public.agency_verification_requests') IS NOT NULL THEN
    REVOKE INSERT, UPDATE, DELETE ON public.agency_verification_requests FROM authenticated, anon;
  END IF;
END
$$;

-- ───────────────────────────────────────────────────────────────────────────
-- 3. Re-assert the v_agencies read grant (forward-safe; view created by …120006).
-- ───────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'v_agencies') THEN
    GRANT SELECT ON public.v_agencies TO anon, authenticated;
  END IF;
END
$$;
