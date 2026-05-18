-- Phase 9 advisor follow-up: relax latest_rates_for_base from SECURITY DEFINER
-- to SECURITY INVOKER. The function is read-only and only SELECTs from
-- public.exchange_rates, which anon already has SELECT access to via the RLS
-- policy from migration 2 (exchange_rates_select USING true). DEFINER was
-- unnecessary and triggered the anon_security_definer_function_executable
-- advisor. SECURITY INVOKER eliminates the advisor warning and reduces attack
-- surface (runs as caller, not owner), with no behavioral change for callers.
--
-- Pattern: Phase 7/9 SECURITY DEFINER is reserved for writes that need RLS
-- bypass (mutate_role, update_exchange_rate). Read-only helpers should be
-- SECURITY INVOKER.

CREATE OR REPLACE FUNCTION public.latest_rates_for_base(p_base_currency TEXT)
RETURNS TABLE (target_currency TEXT, rate NUMERIC, effective_at TIMESTAMPTZ)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT DISTINCT ON (er.target_currency)
    er.target_currency,
    er.rate,
    er.effective_at
  FROM public.exchange_rates er
  WHERE er.base_currency = p_base_currency
    AND er.effective_at <= now()
  ORDER BY er.target_currency, er.effective_at DESC, er.created_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.latest_rates_for_base(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.latest_rates_for_base(TEXT) TO anon, authenticated;
