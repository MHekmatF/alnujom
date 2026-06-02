-- Migration: app_settings advisor hardening (privilege tightening)
-- Phase 23 — App Settings (specs/023-app-settings)
-- See: data-model.md §1.4
-- Apply via: Supabase MCP apply_migration(name='20260602120017_app_settings_advisor_hardening', query='<file body>')
--
-- Re-asserts least-privilege grants so the Supabase linter stays clean even if an
-- earlier create-or-replace is later re-applied. RLS is already ON (…014) and all
-- client writes REVOKEd, so no RLS-disabled-table advisor applies.
-- Idempotent: REVOKE/GRANT/COMMENT are unconditional and safely re-runnable.

-- (a) Table: strip default PUBLIC privileges, re-grant only SELECT to client roles.
REVOKE ALL ON public.app_settings FROM PUBLIC;
GRANT  SELECT ON public.app_settings TO anon, authenticated;

-- (b) RPC: re-assert no PUBLIC execute on the write boundary.
REVOKE EXECUTE ON FUNCTION public.set_app_setting(TEXT, JSONB) FROM PUBLIC;

-- (c) Documentation comment.
COMMENT ON TABLE public.app_settings IS
  'Admin-tunable app-wide settings (Phase 23). Per-key public/sensitive read; writes via set_app_setting() only.';
