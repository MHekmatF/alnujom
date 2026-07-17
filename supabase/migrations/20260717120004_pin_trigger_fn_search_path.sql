-- 20260717120004_pin_trigger_fn_search_path
--
-- QA E2E fix — SEC-L3: pin the mutable search_path on 3 trigger functions
-- (advisor `function_search_path_mutable`). These are NOT SECURITY DEFINER — they run
-- as the table owner via triggers — so the risk is low, but a role-mutable search_path
-- is a standard hardening finding. pg_catalog stays implicitly first; they only touch
-- public objects, so pinning to `public` is safe.
alter function public.set_updated_at() set search_path = public;
alter function public.listing_status_transition_trigger_fn() set search_path = public;
alter function public.listing_media_cap_check() set search_path = public;
