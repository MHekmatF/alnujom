-- 20260706172906_035_revoke_anon_admin_verification
--
-- RECONSTRUCTED 2026-07-17 from the live database (commit-only — already applied
-- via Supabase MCP on 2026-07-06 as tracker version 20260706172906). DO NOT
-- re-apply through MCP (DB-1 fix). Verified live: anon cannot EXECUTE this RPC,
-- authenticated can (the function's own permission check then gates the write).
--
-- Phase 035 Stage 3 — a new function is granted EXECUTE to PUBLIC (anon+authenticated)
-- by default; strip anon so the admin verification RPC is never reachable unauthenticated.
revoke execute on function public.admin_set_listing_verification(uuid, boolean) from anon;
