-- Phase 9: Currencies & Exchange Rates - currencies table.
-- FR-001/002/004/007/007a/008/009.
-- Anonymous SELECT carve-out - see research.md R-04 and R-16.
-- Triggers are attached before seed INSERTs so seeded rows are audited (R-08).

CREATE TABLE IF NOT EXISTS public.currencies (
  code             TEXT        PRIMARY KEY CHECK (code ~ '^[A-Z]{3}$'),
  name_ar          TEXT        NOT NULL CHECK (length(trim(name_ar)) > 0),
  name_en          TEXT        NOT NULL CHECK (length(trim(name_en)) > 0),
  symbol           TEXT        NOT NULL CHECK (length(trim(symbol)) > 0),
  is_active        BOOLEAN     NOT NULL DEFAULT true,
  sort_order       INTEGER     NOT NULL DEFAULT 100,
  is_system        BOOLEAN     NOT NULL DEFAULT false,
  display_decimals SMALLINT    NOT NULL DEFAULT 2 CHECK (display_decimals BETWEEN 0 AND 8),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.currencies ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS set_currencies_updated_at ON public.currencies;
CREATE TRIGGER set_currencies_updated_at
  BEFORE UPDATE ON public.currencies
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.enforce_currency_system_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' AND OLD.is_system = true THEN
    RAISE EXCEPTION 'cannot delete system currency %', OLD.code
      USING ERRCODE = '42501';
  ELSIF TG_OP = 'UPDATE' AND OLD.is_system = true AND NEW.code <> OLD.code THEN
    RAISE EXCEPTION 'cannot rename system currency code (% -> %)', OLD.code, NEW.code
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS enforce_currency_system_immutability ON public.currencies;
CREATE TRIGGER enforce_currency_system_immutability
  BEFORE UPDATE OR DELETE ON public.currencies
  FOR EACH ROW EXECUTE FUNCTION public.enforce_currency_system_immutability();

DROP TRIGGER IF EXISTS audit_currencies_insert ON public.currencies;
DROP TRIGGER IF EXISTS audit_currencies_update ON public.currencies;
DROP TRIGGER IF EXISTS audit_currencies_delete ON public.currencies;

CREATE TRIGGER audit_currencies_insert
  AFTER INSERT ON public.currencies
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('currency.created', '*', 'code');

CREATE TRIGGER audit_currencies_update
  AFTER UPDATE ON public.currencies
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('currency.updated', '*', 'code');

CREATE TRIGGER audit_currencies_delete
  AFTER DELETE ON public.currencies
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('currency.deleted', '*', 'code');

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

INSERT INTO public.currencies (code, name_ar, name_en, symbol, is_active, sort_order, display_decimals, is_system) VALUES
  ('SYP', 'ليرة سورية',    'Syrian Pound', 'ل.س', true, 10, 0, true),
  ('USD', 'دولار أمريكي',  'US Dollar',    '$',   true, 20, 2, true)
ON CONFLICT (code) DO NOTHING;
