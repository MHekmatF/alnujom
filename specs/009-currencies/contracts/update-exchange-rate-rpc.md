# Contract: `public.update_exchange_rate(...)` RPC

**Owner**: Phase 9, migration 3 (`20260518120003_create_update_exchange_rate_rpc.sql`).
**Consumers**: `SetExchangeRatePage` BLoC → `set_exchange_rate.dart` use case → `CurrenciesRepository.setExchangeRate(...)` → `supabase.rpc('update_exchange_rate', ...)`.

## Signature

```sql
public.update_exchange_rate(
  p_base_currency   TEXT,
  p_target_currency TEXT,
  p_rate            NUMERIC,
  p_effective_at    TIMESTAMPTZ DEFAULT now(),
  p_source          TEXT        DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=public,auth
```

## Obligations

1. **Permission check (FR-012a)**: First, the function calls `public.current_user_has_permission('currencies.manage')`. If false, raises `SQLSTATE 42501` with message `'permission denied: currencies.manage required'`.

2. **Input validation**:
   - If `p_base_currency = p_target_currency`: raises `SQLSTATE 22023` with message `'base_currency and target_currency must differ'`.
   - If `p_rate <= 0`: raises `SQLSTATE 22023` with message `'rate must be positive (got <p_rate>)'`.
   - If `p_source IS NOT NULL AND length(p_source) > 500`: the CHECK constraint on `exchange_rates.source` raises `SQLSTATE 23514` — the function may pre-validate and raise 22023 for nicer error wording.
   - The FK constraints on `base_currency` / `target_currency` reject unknown 3-letter codes with `SQLSTATE 23503`.

3. **Atomic two-INSERT (R-06 / Q2)**: The function INSERTs **two rows** in a single transaction:
   - Row 1 (admin-authored): `(p_base_currency, p_target_currency, p_rate, p_effective_at, auth.uid(), p_source)`. Captures the inserted row's UUID into `v_admin_row_id`.
   - Row 2 (auto-derived inverse): `(p_target_currency, p_base_currency, round(1.0 / p_rate, 6), p_effective_at, auth.uid(), format('auto-derived from %s', v_admin_row_id))`.

4. **Banker's rounding (R-11)**: The derived rate uses Postgres `round(NUMERIC, INTEGER)` which applies half-to-even rounding by default for the requested scale. No other rounding mode.

5. **Return shape**: A JSONB object:
   ```json
   {
     "admin_row":   { /* full row from public.exchange_rates */ },
     "derived_row": { /* full row from public.exchange_rates */ }
   }
   ```

6. **Audit-trigger side effect**: The two INSERTs each fire the `audit_exchange_rates_insert` trigger, producing exactly two `audit_logs` rows with `action='exchange_rate.updated'`, `actor_user_id=auth.uid()`, and the inserted-row JSONB in `after_state` (US8 acceptance scenario 4).

7. **EXECUTE grant** (per migration 5 / R-21 hardening):
   - `REVOKE EXECUTE ON FUNCTION public.update_exchange_rate(TEXT, TEXT, NUMERIC, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon`.
   - `GRANT EXECUTE ON FUNCTION public.update_exchange_rate(TEXT, TEXT, NUMERIC, TIMESTAMPTZ, TEXT) TO authenticated`.

## Verification

```sql
-- Function exists with correct signature and security
SELECT proname, pg_get_function_identity_arguments(oid) as args, prosecdef, lanname
FROM pg_proc p JOIN pg_language l ON p.prolang = l.oid
WHERE proname = 'update_exchange_rate' AND pronamespace = 'public'::regnamespace;
-- Expected: 1 row, args = 'p_base_currency text, p_target_currency text, p_rate numeric, p_effective_at timestamp with time zone, p_source text', prosecdef=t, lanname='plpgsql'

-- Permission denied for non-admin
-- (with a JWT for a non-permission-holder)
SELECT public.update_exchange_rate('USD', 'SYP', 15000);
-- Expected: ERROR 42501: permission denied: currencies.manage required

-- Base = target rejected
-- (with admin JWT)
SELECT public.update_exchange_rate('USD', 'USD', 1);
-- Expected: ERROR 22023: base_currency and target_currency must differ

-- Successful call returns both rows
SELECT public.update_exchange_rate('USD', 'SYP', 15000) AS result;
-- Expected: JSONB with admin_row + derived_row keys; derived_row.rate ≈ 0.000067

-- Two rows actually persisted
SELECT count(*) FROM public.exchange_rates WHERE created_at > now() - interval '1 minute';
-- Expected: 2 (or more if other admins are active)

-- Two audit rows emitted per call
SELECT count(*) FROM public.audit_logs WHERE action = 'exchange_rate.updated' AND created_at > now() - interval '1 minute';
-- Expected: 2 (or more if other admins are active)
```

## Forbidden

- UPDATE or DELETE statements anywhere in the function body. The append-only invariant (R-08) is preserved by the RLS policies; the function must not bypass it.
- Calling `log_audit` directly. The trigger handles audit emission as a side-effect (R-05).
- Returning the inserted rows as anything other than the documented JSONB shape (Flutter parses `{admin_row, derived_row}`).
- `SECURITY INVOKER` instead of `SECURITY DEFINER`. The function must run with elevated privileges to bypass the explicit deny policies on `exchange_rates` UPDATE/DELETE that would otherwise reject even the INSERT (though INSERT is explicitly allowed, the SECURITY DEFINER posture mirrors Phase 7's `mutate_role` precedent and avoids any future RLS policy interaction).
