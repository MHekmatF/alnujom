-- Mirror of the inline RLS policies in supabase/migrations/20260518120002_create_exchange_rates.sql. R-02 dual-storage invariant. The deny_update + deny_delete policies make the append-only invariant explicit even though Postgres RLS defaults to deny when no policy matches.

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
