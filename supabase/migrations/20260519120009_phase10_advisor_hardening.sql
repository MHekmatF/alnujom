-- Phase 10: advisor hardening after listings migrations.
-- T026: address new advisor findings from Phase 10 artifacts.

-- The publisher-listings view is a query helper and must inherit underlying RLS.
-- Postgres 15 views are SECURITY DEFINER by default unless security_invoker is set.
ALTER VIEW public.v_publisher_listings SET (security_invoker = true);
REVOKE ALL ON TABLE public.v_publisher_listings FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.v_publisher_listings TO authenticated;

-- Trigger helper functions should have immutable search_path posture.
ALTER FUNCTION public.listing_visibility_sync_trigger_fn() SET search_path = public, auth;
ALTER FUNCTION public.listing_status_transition_trigger_fn() SET search_path = public, auth;

-- Trigger functions execute via triggers; direct RPC execution is not part of the API.
REVOKE EXECUTE ON FUNCTION public.listings_audit_trigger_fn() FROM PUBLIC, anon, authenticated;

-- FK index hardening for new Phase 10 tables.
CREATE INDEX IF NOT EXISTS idx_listings_city_id ON public.listings (city_id);
CREATE INDEX IF NOT EXISTS idx_listings_area_id ON public.listings (area_id);
CREATE INDEX IF NOT EXISTS idx_listing_prices_currency_code ON public.listing_prices (currency_code);
CREATE INDEX IF NOT EXISTS idx_listing_status_history_changed_by ON public.listing_status_history (changed_by);
CREATE INDEX IF NOT EXISTS idx_listing_visibility_last_updated_by ON public.listing_visibility (last_updated_by);
