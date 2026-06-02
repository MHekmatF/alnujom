-- Mirror of the inline RLS policy in supabase/migrations/20260602120014_create_app_settings.sql.
-- Dual-storage invariant (Principle II) — both files MUST be kept in sync at PR review.
-- Phase 23 — App Settings (specs/023-app-settings, R-197/R-199).

-- SELECT: per-key public/sensitive read.
--   Public keys (is_public=true) are readable by anyone, including anonymous clients.
--   Sensitive keys (is_public=false) are readable only by settings.manage holders.
-- No TO clause: the policy applies to every role the table is GRANTed SELECT on
-- (anon + authenticated), matching the migration.
DROP POLICY IF EXISTS app_settings_select ON public.app_settings;
CREATE POLICY app_settings_select ON public.app_settings
  FOR SELECT
  USING (is_public OR public.current_user_has_permission('settings.manage'));

-- No INSERT / UPDATE / DELETE policies exist by design.
-- All direct client writes are REVOKEd (see migration …014 / hardening …017);
-- the ONLY mutation path is the SECURITY DEFINER RPC public.set_app_setting(),
-- which re-checks settings.manage server-side and is audited via trg_app_settings_audit.
