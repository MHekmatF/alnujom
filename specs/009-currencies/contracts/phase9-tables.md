# Contract: Phase 9 Tables (`currencies`, `exchange_rates`)

**Owner**: Phase 9, migrations `20260518120001_create_currencies.sql` + `20260518120002_create_exchange_rates.sql`.
**Consumers**: every Phase 9 contract below; Phase 10 listing form (`listing_prices.currency_code` FK target); Phase 13 / 14 / 15 read paths.

## Obligations

The two tables MUST be created with the exact column shapes, constraints, indexes, and RLS-enabled state captured in [data-model.md § Tables](../data-model.md). The full CREATE TABLE bodies are normative.

In particular:

1. **`public.currencies`**:
   - PRIMARY KEY is `code TEXT` with `CHECK (code ~ '^[A-Z]{3}$')`.
   - `name_ar`, `name_en`, `symbol` are NOT NULL and non-empty (`length(trim(...)) > 0`).
   - `display_decimals SMALLINT` is constrained `BETWEEN 0 AND 8`.
   - RLS is enabled (`ENABLE ROW LEVEL SECURITY`).
   - `set_updated_at` trigger (Phase 4 helper) is attached unchanged.

2. **`public.exchange_rates`**:
   - PRIMARY KEY is `id UUID DEFAULT gen_random_uuid()`.
   - `base_currency` and `target_currency` BOTH reference `public.currencies(code) ON DELETE RESTRICT`.
   - `rate NUMERIC(18, 6) CHECK (rate > 0)` (R-10).
   - `CHECK (base_currency <> target_currency)`.
   - Composite index `(base_currency, target_currency, effective_at DESC)` for the latest-rate-lookup query path.
   - RLS is enabled.

3. **No additional columns may be added** without updating this contract and the spec's data-model.md.

## Verification

```sql
-- Both tables exist with RLS enabled
SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('currencies', 'exchange_rates');
-- Expected: 2 rows, both rowsecurity=t

-- currencies columns
SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns
WHERE table_schema='public' AND table_name='currencies' ORDER BY ordinal_position;
-- Expected: 10 columns matching data-model.md

-- exchange_rates columns
SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns
WHERE table_schema='public' AND table_name='exchange_rates' ORDER BY ordinal_position;
-- Expected: 8 columns matching data-model.md

-- Composite index exists
SELECT indexname, indexdef FROM pg_indexes WHERE tablename='exchange_rates' AND indexname='idx_exchange_rates_base_target_effective';
-- Expected: 1 row with the (base_currency, target_currency, effective_at DESC) shape
```

## Forbidden

- Renaming `code` to anything other than `code` (downstream contracts read this name).
- Changing `NUMERIC(18, 6)` precision/scale on `rate` (R-10 lock-in; downstream callers depend on the precision contract).
- Adding an `is_active` column to `exchange_rates` (rates are append-only; deactivation is not a concept for historical rows).
- Adding an UPDATE or DELETE policy to `exchange_rates` (R-08 append-only invariant; FR-008).
