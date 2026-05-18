-- Mirror of the inline RLS policies in supabase/migrations/20260518120001_create_currencies.sql. R-02 dual-storage invariant - both files MUST be kept in sync at PR review.

-- SELECT: public read (anon + authenticated)
DROP POLICY IF EXISTS currencies_select ON public.currencies;
CREATE POLICY currencies_select ON public.currencies
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT / UPDATE / DELETE: currencies.manage holders only
DROP POLICY IF EXISTS currencies_insert ON public.currencies;
CREATE POLICY currencies_insert ON public.currencies
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_has_permission('currencies.manage'));

DROP POLICY IF EXISTS currencies_update ON public.currencies;
CREATE POLICY currencies_update ON public.currencies
  FOR UPDATE
  TO authenticated
  USING (public.current_user_has_permission('currencies.manage'))
  WITH CHECK (public.current_user_has_permission('currencies.manage'));

DROP POLICY IF EXISTS currencies_delete ON public.currencies;
CREATE POLICY currencies_delete ON public.currencies
  FOR DELETE
  TO authenticated
  USING (public.current_user_has_permission('currencies.manage'));
