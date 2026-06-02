-- Migration: Create app_settings table + RLS + per-key SELECT + REVOKE client writes
-- Phase 23 — App Settings (specs/023-app-settings)
-- See: data-model.md §1.1, contracts/phase23-app-settings-table.md (R-197, R-199)
-- Apply via: Supabase MCP apply_migration(name='20260602120014_create_app_settings', query='<file body>')
--
-- Reuses (does NOT redefine):
--   - public.set_updated_at()                  (Phase 4, 20260506120002_create_profiles.sql)
--   - public.current_user_has_permission(text) (Phase 6, 20260515120005_create_permission_predicate.sql)
-- Idempotent: CREATE TABLE IF NOT EXISTS, DROP POLICY/TRIGGER IF EXISTS guards.

-- (a) app_settings table
CREATE TABLE IF NOT EXISTS public.app_settings (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL,
  description TEXT,
  is_public   BOOLEAN NOT NULL DEFAULT true,
  updated_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- (b) Row Level Security
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- (c) Read: public keys readable by anyone (incl. anon); sensitive keys only by
--     settings.manage holders (R-197 — per-key public/sensitive read).
GRANT SELECT ON public.app_settings TO anon, authenticated;

DROP POLICY IF EXISTS app_settings_select ON public.app_settings;
CREATE POLICY app_settings_select ON public.app_settings
  FOR SELECT
  USING (is_public OR public.current_user_has_permission('settings.manage'));

-- (d) No direct client writes — mutation ONLY via set_app_setting() (R-199).
REVOKE INSERT, UPDATE, DELETE ON public.app_settings FROM anon, authenticated;

-- (e) updated_at maintenance (reuse the Phase 4 helper).
DROP TRIGGER IF EXISTS trg_app_settings_set_updated_at ON public.app_settings;
CREATE TRIGGER trg_app_settings_set_updated_at
  BEFORE UPDATE ON public.app_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
