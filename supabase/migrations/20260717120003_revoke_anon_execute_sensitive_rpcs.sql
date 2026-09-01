-- 20260717120003_revoke_anon_execute_sensitive_rpcs
--
-- QA E2E fix — SEC-M3 (defense-in-depth): new SECURITY DEFINER functions get default
-- anon EXECUTE (the documented project footgun). These 10 are authenticated-only
-- vault / PII-decrypt / agency-management RPCs — they already fail closed for anon
-- (they check auth.uid()/permissions), but there is no reason for anon to hold EXECUTE.
--
-- Scope is deliberately narrow: verified 0 RLS-policy references for each (so revoking
-- cannot trigger the 42501 anon-policy footgun), and NONE are guest-callable RPCs,
-- RLS-predicate helpers, trigger functions, or functions used by anon-facing views
-- (map_jitter_coordinates, is_agency_member, search_listings, search_map, submit_inquiry,
-- record_ad_event, list_video_reels are intentionally left with anon EXECUTE). The broader
-- authenticated_security_definer_function set is out of scope (those are authorization-checked
-- and not anon-reachable).
--
-- Verified live 2026-07-17: after this migration anon can EXECUTE 0 of the 10; the public
-- + RLS-helper functions above still have anon EXECUTE.
revoke execute on function public.app_vault_secret_for_agency(uuid, text) from anon;
revoke execute on function public.app_vault_set_agency_secret(uuid, text, text) from anon;
revoke execute on function public.decrypt_inquirer_phone(uuid) from anon;
revoke execute on function public.create_agency(text, text, text, text, text) from anon;
revoke execute on function public.invite_agency_member(uuid, text, text) from anon;
revoke execute on function public.remove_agency_member(uuid, uuid) from anon;
revoke execute on function public.respond_agency_invitation(uuid, boolean) from anon;
revoke execute on function public.set_agency_member_role(uuid, uuid, text) from anon;
revoke execute on function public.submit_agency_verification(uuid, text, text, jsonb) from anon;
revoke execute on function public.update_agency_profile(uuid, text, text, text, text, text, text, text) from anon;
