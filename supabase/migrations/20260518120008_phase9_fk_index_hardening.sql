-- Phase 9: Advisor hardening for Phase 9 foreign keys.
-- Supabase performance advisor reported these FK columns without covering indexes
-- during the Phase 11 pass. Keep this migration additive and idempotent.
--
-- Naming note: this file's prefix was bumped from 20260518120007 to ...008 in
-- Phase 11 review to avoid colliding with
-- 20260518120007_relax_latest_rates_for_base_to_security_invoker.sql. The remote
-- project (already applied) tracks the original 007-prefixed name; a fresh
-- deploy from this branch will re-apply under the 008 name -- safe and
-- idempotent thanks to CREATE INDEX IF NOT EXISTS.

CREATE INDEX IF NOT EXISTS idx_exchange_rates_target_currency
  ON public.exchange_rates (target_currency);

CREATE INDEX IF NOT EXISTS idx_exchange_rates_set_by
  ON public.exchange_rates (set_by);

CREATE INDEX IF NOT EXISTS idx_user_preferences_display_currency
  ON public.user_preferences (display_currency);
