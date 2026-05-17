-- Phase 9: Advisor hardening for currencies + exchange_rates + update_exchange_rate RPC.
-- Source: specs/009-currencies/research.md R-04 (anon SELECT carve-out) + R-16 (documented in migration comments).
-- Pattern: codify anon GRANTs explicitly + REVOKE write surfaces from anon as defense-in-depth on top of RLS; tighten RPC EXECUTE grants.

GRANT SELECT ON public.currencies TO anon, authenticated;
GRANT SELECT ON public.exchange_rates TO anon, authenticated;

REVOKE INSERT, UPDATE, DELETE ON public.currencies FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.exchange_rates FROM anon;

REVOKE EXECUTE ON FUNCTION public.update_exchange_rate(TEXT, TEXT, NUMERIC, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_exchange_rate(TEXT, TEXT, NUMERIC, TIMESTAMPTZ, TEXT) TO authenticated;

-- Trigger-only function: never exposed through PostgREST RPC.
REVOKE EXECUTE ON FUNCTION public.enforce_currency_system_immutability() FROM PUBLIC, anon, authenticated;
