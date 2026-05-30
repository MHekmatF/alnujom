-- Phase 18 (spec/018-reports-moderation) — revoke the default anon EXECUTE grant.
--
-- Supabase auto-grants EXECUTE on new public functions to `anon` (default
-- privileges), which a bare `REVOKE ... FROM PUBLIC` does not remove — the same
-- quirk Phase 17 handled in 20260529120007_favorites_revoke_anon_execute.
-- submit_report (FR-010(a)) and start_report_review must be authenticated-only.
-- Both function bodies already reject anonymous callers (auth_required /
-- permission_denied), so this is defense-in-depth matching the stated grant
-- posture — not a live vulnerability fix.
--
-- resolve_report_internal is already service_role-only (no anon grant), so it is
-- not listed here.

REVOKE EXECUTE ON FUNCTION public.submit_report(UUID, TEXT, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.start_report_review(UUID) FROM anon;
