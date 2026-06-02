-- Migration: Fix anon read of public app_settings (RLS function-grant gotcha)
-- Phase 23 — App Settings (specs/023-app-settings)
--
-- BUG (found in Phase-23 Polish wire-level testing, T029): the single SELECT policy
--   USING (is_public OR public.current_user_has_permission('settings.manage'))
-- is granted to PUBLIC (anon + authenticated). `current_user_has_permission` is
-- SECURITY DEFINER with EXECUTE granted to authenticated/service_role only — Phase 6/22
-- hardening intentionally revoked it from anon/PUBLIC. Postgres does NOT short-circuit
-- `is_public OR f()` past the function's EXECUTE-privilege check, so an anon SELECT
-- (a logged-out app session loading public settings) failed with
--   42501: permission denied for function current_user_has_permission.
-- Every other policy referencing this predicate is scoped TO authenticated — app_settings
-- was the only PUBLIC-scoped one, so it was the only place the gotcha bit.
--
-- FIX: split into two permissive SELECT policies (OR-combined by Postgres):
--   1. a function-free public-read (is_public) for everyone (anon + authenticated), and
--   2. an admin-read for sensitive (is_public=false) keys, scoped TO authenticated
--      (the only role that can EXECUTE current_user_has_permission).
-- This preserves the per-key public/sensitive semantics WITHOUT re-granting the
-- deliberately-revoked predicate to anon. Idempotent: DROP POLICY IF EXISTS guards.

-- Replace the single combined policy.
DROP POLICY IF EXISTS app_settings_select ON public.app_settings;

-- (1) Public keys: readable by anyone, no permission-function call.
DROP POLICY IF EXISTS app_settings_select_public ON public.app_settings;
CREATE POLICY app_settings_select_public ON public.app_settings
  FOR SELECT
  USING (is_public);

-- (2) Sensitive keys (is_public=false): only settings.manage holders. Scoped to
--     authenticated — anon never evaluates the predicate (no EXECUTE, and anon can
--     never hold a permission anyway).
DROP POLICY IF EXISTS app_settings_select_admin ON public.app_settings;
CREATE POLICY app_settings_select_admin ON public.app_settings
  FOR SELECT
  TO authenticated
  USING (public.current_user_has_permission('settings.manage'));
