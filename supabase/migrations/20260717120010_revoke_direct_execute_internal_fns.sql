-- 20260717120010_revoke_direct_execute_internal_fns
--
-- QA E2E security (API surface): strip needless direct-call EXECUTE grants on
-- internal SECURITY DEFINER functions flagged by the anon_security_definer
-- advisor. None of these are meant to be called over PostgREST/RPC.
--
-- The four trigger functions return `trigger`, run as the table owner when the
-- trigger fires, and PostgreSQL does NOT check EXECUTE on a trigger function
-- against the session role — so revoking every direct-call grant cannot break
-- the triggers, it only removes them as a probe/attack surface.
--
-- Deliberately NOT revoked here:
--   * map_jitter_coordinates — called by the security_invoker view
--     v_listings_map_public, so anon needs EXECUTE for the public map to work.
--   * is_agency_admin / is_agency_member / publisher_owns_approved_listing —
--     bool predicates used inside RLS policies; they return false for anon and
--     leak nothing, and revoking risks 42501 in anon-scoped policies.
--   * search_listings / search_map / list_video_reels / market_* / publisher_*
--     / record_ad_event / record_lead_event / submit_inquiry — genuine
--     anonymous-guest features (validated + PII-encrypting; see audit).
revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;
revoke execute on function public.notify_saved_search_matches() from public, anon, authenticated;
revoke execute on function public.bump_conversation_last_message() from public, anon, authenticated;
revoke execute on function public.enforce_inquiry_transition() from public, anon, authenticated;

-- The inbox unread-count is an authenticated-only feature (keyed on auth.uid());
-- anon has no inbox. Keep authenticated + service_role; drop anon.
revoke execute on function public.get_inbox_unread_count() from anon;
