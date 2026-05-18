-- Phase 9: create update_exchange_rate RPC.
-- FR-012 + R-06 + R-11.
-- The implementation plan's Edge Function wording is intentionally implemented
-- as a SECURITY DEFINER PL/pgSQL RPC, matching the Phase 7 precedent.
-- R-11 refinement (2026-05-17): banker's rounding is enforced at the display
-- layer (MoneyFormatter._roundHalfEven). This RPC uses Postgres's built-in
-- round() which is half-away-from-zero; the divergence is intentional and
-- documented in specs/009-currencies/research.md R-11.

CREATE OR REPLACE FUNCTION public.update_exchange_rate(
  p_base_currency   TEXT,
  p_target_currency TEXT,
  p_rate            NUMERIC,
  p_effective_at    TIMESTAMPTZ DEFAULT now(),
  p_source          TEXT        DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_row     public.exchange_rates%ROWTYPE;
  v_derived_row   public.exchange_rates%ROWTYPE;
  v_derived_rate  NUMERIC(18, 6);
BEGIN
  IF NOT public.current_user_has_permission('currencies.manage') THEN
    RAISE EXCEPTION 'permission denied: currencies.manage required'
      USING ERRCODE = '42501';
  END IF;

  IF p_base_currency = p_target_currency THEN
    RAISE EXCEPTION 'base_currency and target_currency must differ'
      USING ERRCODE = '22023';
  END IF;

  IF p_rate <= 0 THEN
    RAISE EXCEPTION 'rate must be positive (got %)', p_rate
      USING ERRCODE = '22023';
  END IF;

  v_derived_rate := round(1.0 / p_rate, 6);

  INSERT INTO public.exchange_rates (base_currency, target_currency, rate, effective_at, set_by, source)
  VALUES (p_base_currency, p_target_currency, p_rate, p_effective_at, auth.uid(), p_source)
  RETURNING * INTO v_admin_row;

  INSERT INTO public.exchange_rates (base_currency, target_currency, rate, effective_at, set_by, source)
  VALUES (p_target_currency, p_base_currency, v_derived_rate, p_effective_at, auth.uid(),
          format('auto-derived from %s', v_admin_row.id))
  RETURNING * INTO v_derived_row;

  RETURN jsonb_build_object(
    'admin_row',   to_jsonb(v_admin_row),
    'derived_row', to_jsonb(v_derived_row)
  );
END;
$$;
