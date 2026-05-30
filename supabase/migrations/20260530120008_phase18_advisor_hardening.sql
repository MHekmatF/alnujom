-- Phase 18 (spec/018-reports-moderation) — Sub-Phase E (T021) — advisor hardening.
-- Matches the Phase 16/17 advisor-hardening files (20260527120012 / 20260529120005).
--
-- Safety-net ALTER FUNCTION … SET search_path for the 3 Phase-18 functions +
-- re-assert grants + re-assert table REVOKEs + GRANT SELECT on the view.
--
-- APPLY-ORDER NOTE: submit_report is created by migration 20260530120006
-- (Sub-Phase D) and v_reports by 20260530120004 (Sub-Phase C). Both sort BEFORE
-- this file (…120008), so under in-order migration apply they always exist by the
-- time this runs. The submit_report ALTER + grant and the v_reports GRANT below
-- are nevertheless wrapped in EXISTS guards so this hardening file is forward-safe
-- even if the C/D migrations have not yet landed in a given environment (it then
-- no-ops those statements rather than erroring). resolve_report_internal and
-- start_report_review are created by 20260530120007 (this same Sub-Phase E).

-- ── search_path hardening (idempotent) ──
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'submit_report'
  ) THEN
    ALTER FUNCTION public.submit_report(UUID, TEXT, TEXT) SET search_path = pg_catalog, public;
    REVOKE ALL ON FUNCTION public.submit_report(UUID, TEXT, TEXT) FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.submit_report(UUID, TEXT, TEXT) TO authenticated;
  END IF;
END
$$;

ALTER FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT)
  SET search_path = public, pg_temp;
ALTER FUNCTION public.start_report_review(UUID)
  SET search_path = public, pg_temp;

-- ── Re-assert function grants (idempotent) ──
REVOKE ALL ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_report_internal(UUID, UUID, TEXT, TEXT) TO service_role;

REVOKE ALL ON FUNCTION public.start_report_review(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_report_review(UUID) TO authenticated;

-- ── Re-assert table write-lockdown (RPC-only writes; no client mutation) ──
REVOKE INSERT, UPDATE, DELETE ON public.reports FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.moderation_actions FROM authenticated, anon;

-- ── Re-assert view read grant (forward-safe; view created by …120004) ──
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_views
    WHERE schemaname = 'public' AND viewname = 'v_reports'
  ) THEN
    GRANT SELECT ON public.v_reports TO authenticated;
  END IF;
END
$$;
