-- Phase 9 helper: latest rate per (base, target) pair for a given base currency.
-- Read-only; reuses the idx_exchange_rates_base_target_effective composite index
-- via DISTINCT ON. Anonymous + authenticated may call (read-only, same posture
-- as the SELECT policy on public.exchange_rates).

CREATE OR REPLACE FUNCTION public.latest_rates_for_base(p_base_currency TEXT)
RETURNS TABLE (target_currency TEXT, rate NUMERIC, effective_at TIMESTAMPTZ)
LANGUAGE sql
STABLE
SECURITY DEFINER
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
