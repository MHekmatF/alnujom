-- Mirror of the inline RLS policy in supabase/migrations/20260602120014_create_app_settings.sql.
-- Dual-storage invariant (Principle II) — both files MUST be kept in sync at PR review.
-- Phase 23 — App Settings (specs/023-app-settings, R-197/R-199).

-- SELECT: per-key public/sensitive read, split into TWO permissive policies
-- (migration …019). The original single policy combined is_public with
-- current_user_has_permission(), but that predicate's EXECUTE is granted to
-- authenticated/service_role only (Phase 6/22 hardening revoked it from anon/PUBLIC),
-- so a PUBLIC-scoped policy referencing it made anon SELECTs fail with 42501. The two
-- permissive policies below are OR-combined by Postgres and keep the same semantics
-- without ever asking anon to evaluate the predicate.
--
--   (1) Public keys (is_public=true): readable by anyone, including anonymous clients.
DROP POLICY IF EXISTS app_settings_select ON public.app_settings;
DROP POLICY IF EXISTS app_settings_select_public ON public.app_settings;
CREATE POLICY app_settings_select_public ON public.app_settings
  FOR SELECT
  USING (is_public);

--   (2) Sensitive keys (is_public=false): readable only by settings.manage holders.
--       Scoped TO authenticated — the only role that can EXECUTE the predicate.
DROP POLICY IF EXISTS app_settings_select_admin ON public.app_settings;
CREATE POLICY app_settings_select_admin ON public.app_settings
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('settings.manage'));

-- No INSERT / UPDATE / DELETE policies exist by design.
-- All direct client writes are REVOKEd (see migration …014 / hardening …017);
-- the ONLY mutation path is the SECURITY DEFINER RPC public.set_app_setting(),
-- which re-checks settings.manage server-side and is audited via trg_app_settings_audit.
