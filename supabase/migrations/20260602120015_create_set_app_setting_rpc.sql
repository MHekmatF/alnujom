-- Migration: set_app_setting() definer write RPC + grants + audit trigger
-- Phase 23 — App Settings (specs/023-app-settings)
-- See: data-model.md §1.2, contracts/phase23-set-app-setting-rpc-and-audit.md (R-199, R-200)
-- Apply via: Supabase MCP apply_migration(name='20260602120015_create_set_app_setting_rpc', query='<file body>')
--
-- Reuses (does NOT redefine):
--   - public.current_user_has_permission(text) (Phase 6) — server-side re-check (Principle III)
--   - public.log_audit() trigger fn            (Phase 4, 20260506120004_create_audit_logs.sql)
-- The ONLY write path to public.app_settings (all client writes REVOKEd in …014/…017).
-- Idempotent: CREATE OR REPLACE FUNCTION, DROP TRIGGER IF EXISTS guard.

-- (a) set_app_setting() — the single, audited, permission-boundaried mutation path.
CREATE OR REPLACE FUNCTION public.set_app_setting(p_key TEXT, p_value JSONB)
RETURNS public.app_settings
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
  v_row public.app_settings;
BEGIN
  -- Server-side re-check (checks-at-both-ends, Principle III).
  IF NOT public.current_user_has_permission('settings.manage') THEN
    RAISE EXCEPTION 'permission denied: settings.manage required' USING ERRCODE = '42501';
  END IF;

  UPDATE public.app_settings
     SET value = p_value, updated_by = auth.uid(), updated_at = now()
   WHERE key = p_key
  RETURNING * INTO v_row;

  -- Catalog keys are seeded, never client-created.
  IF NOT FOUND THEN
    RAISE EXCEPTION 'unknown app setting key: %', p_key USING ERRCODE = 'P0002';
  END IF;

  RETURN v_row;
END;
$$;

-- (b) Grants — the function is the permission boundary; no anon/PUBLIC execute.
REVOKE EXECUTE ON FUNCTION public.set_app_setting(TEXT, JSONB) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION public.set_app_setting(TEXT, JSONB) TO authenticated;

-- (c) Audit every successful change — the §9.4 "App settings changes (Phase 23)" action (R-200).
--     Reuses the Phase 4 log_audit() trigger fn: args = (action, watched-columns, pk-column).
DROP TRIGGER IF EXISTS trg_app_settings_audit ON public.app_settings;
CREATE TRIGGER trg_app_settings_audit
  AFTER UPDATE ON public.app_settings
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('settings.updated', 'value', 'key');
