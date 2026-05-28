-- Phase 17 — Migration 5/5 — advisor hardening (Phase 16 20260527120012 pattern).
ALTER FUNCTION public.add_favorite(UUID) SET search_path = pg_catalog, public;

-- Safety-net grants (idempotent): only SELECT + DELETE reach the client on the
-- table; INSERT/UPDATE are RPC-only; the view is readable by authenticated.
REVOKE INSERT, UPDATE ON public.favorites FROM authenticated, anon;
GRANT SELECT ON public.v_favorites TO authenticated;

REVOKE ALL ON FUNCTION public.add_favorite(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_favorite(UUID) TO authenticated;
