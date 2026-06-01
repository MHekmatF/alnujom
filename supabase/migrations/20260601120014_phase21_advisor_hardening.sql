-- Phase 21 — advisor hardening. Pin search_path on the new SECURITY DEFINER functions
-- (defense-in-depth) and confirm the view's grants. Idempotent ALTERs.
ALTER FUNCTION public.create_ad(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) SET search_path = public;
ALTER FUNCTION public.update_ad(UUID,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ,BOOLEAN,JSONB) SET search_path = public;
ALTER FUNCTION public.set_ad_active(UUID,BOOLEAN) SET search_path = public;
ALTER FUNCTION public.archive_ad(UUID) SET search_path = public;
ALTER FUNCTION public.record_ad_event(UUID,TEXT) SET search_path = pg_catalog, public;
-- Run get_advisors after applying all Phase 21 migrations; resolve any SECURITY DEFINER /
-- function-search-path / RLS advisories before merge (memory: project_supabase_view_rls_gotchas).
