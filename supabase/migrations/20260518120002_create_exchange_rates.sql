-- Phase 9: Currencies & Exchange Rates - exchange_rates table.
-- FR-001/003/005/007/008/009; R-08, R-10.
-- Append-only by RLS - see FR-008 + R-08; anonymous SELECT carve-out - see R-04.
-- Triggers are attached before seed INSERTs so seeded rows are audited.

CREATE TABLE IF NOT EXISTS public.exchange_rates (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  base_currency   TEXT        NOT NULL REFERENCES public.currencies(code) ON DELETE RESTRICT,
  target_currency TEXT        NOT NULL REFERENCES public.currencies(code) ON DELETE RESTRICT,
  rate            NUMERIC(18, 6) NOT NULL CHECK (rate > 0),
  effective_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  set_by          UUID                 REFERENCES auth.users(id)         ON DELETE SET NULL,
  source          TEXT                                                   CHECK (source IS NULL OR length(source) <= 500),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT exchange_rates_base_neq_target CHECK (base_currency <> target_currency)
);

ALTER TABLE public.exchange_rates ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_exchange_rates_base_target_effective
  ON public.exchange_rates (base_currency, target_currency, effective_at DESC);

DROP TRIGGER IF EXISTS audit_exchange_rates_insert ON public.exchange_rates;
CREATE TRIGGER audit_exchange_rates_insert
  AFTER INSERT ON public.exchange_rates
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('exchange_rate.updated', '*', 'id');

-- SELECT: public read (anon + authenticated)
DROP POLICY IF EXISTS exchange_rates_select ON public.exchange_rates;
CREATE POLICY exchange_rates_select ON public.exchange_rates
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT: currencies.manage holders only (NO UPDATE policy, NO DELETE policy - append-only)
DROP POLICY IF EXISTS exchange_rates_insert ON public.exchange_rates;
CREATE POLICY exchange_rates_insert ON public.exchange_rates
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_has_permission('currencies.manage'));

-- Explicit deny on UPDATE and DELETE for defense-in-depth.
DROP POLICY IF EXISTS exchange_rates_deny_update ON public.exchange_rates;
CREATE POLICY exchange_rates_deny_update ON public.exchange_rates
  FOR UPDATE
  TO authenticated
  USING (false);

DROP POLICY IF EXISTS exchange_rates_deny_delete ON public.exchange_rates;
CREATE POLICY exchange_rates_deny_delete ON public.exchange_rates
  FOR DELETE
  TO authenticated
  USING (false);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.exchange_rates WHERE base_currency = 'USD' AND target_currency = 'SYP') THEN
    INSERT INTO public.exchange_rates (base_currency, target_currency, rate, effective_at, set_by, source) VALUES
      ('USD', 'SYP', 15000.000000, now(), NULL, 'seed'),
      ('SYP', 'USD', round(1.0 / 15000.000000, 6), now(), NULL, 'auto-derived from seed (USD→SYP)');
  END IF;
END $$;
