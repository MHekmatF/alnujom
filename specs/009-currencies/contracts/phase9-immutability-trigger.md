# Contract: `enforce_currency_system_immutability` Trigger

**Owner**: Phase 9, migration 1.
**Consumers**: admin UI (must NOT show Delete or `code`-rename affordances on `is_system=true` rows per FR-015a); RLS layer (relies on this trigger as defense-in-depth).

## Obligations

A `BEFORE UPDATE OR DELETE` PL/pgSQL trigger on `public.currencies` refuses:

1. Any `DELETE` where `OLD.is_system = true`.
2. Any `UPDATE` where `OLD.is_system = true` AND `NEW.code <> OLD.code`.

Both refusals `RAISE EXCEPTION` with `ERRCODE = '42501'` (insufficient_privilege).

The trigger function is `SECURITY DEFINER` with `SET search_path = public` to prevent search-path injection.

The trigger MUST fire BEFORE the audit trigger so that an attempted illegal DELETE/UPDATE does NOT produce an audit row (defense in depth: the audit log records actual mutations, not refused ones).

Other column updates on `is_system=true` rows ARE allowed: `name_ar`, `name_en`, `symbol`, `is_active`, `sort_order`, `display_decimals`, `updated_at`, `created_at` can all be updated.

Body source: see [data-model.md § Triggers § Immutability trigger](../data-model.md).

## Verification

```sql
-- Trigger exists and is BEFORE timing
SELECT trigger_name, action_timing, event_manipulation FROM information_schema.triggers
WHERE event_object_schema='public' AND event_object_table='currencies'
  AND trigger_name = 'enforce_currency_system_immutability'
ORDER BY event_manipulation;
-- Expected: 2 rows (BEFORE DELETE, BEFORE UPDATE)

-- Attempted DELETE of system row is refused
DELETE FROM public.currencies WHERE code = 'USD';
-- Expected: ERROR  42501: cannot delete system currency USD

-- Attempted code-rename of system row is refused
UPDATE public.currencies SET code = 'usdv2' WHERE code = 'USD';
-- Expected: ERROR  42501: cannot rename system currency code (USD → usdv2)

-- Allowed: updating other columns on system row
UPDATE public.currencies SET symbol = '$$' WHERE code = 'USD';
-- Expected: UPDATE 1
UPDATE public.currencies SET symbol = '$' WHERE code = 'USD';  -- restore
```

## Forbidden

- Loosening to permit DELETE on `is_system=true` even when "no FK references the row" — the trigger is unconditional defense-in-depth.
- Tightening to refuse `is_active` UPDATE on `is_system=true` — admins MUST be able to deactivate a system currency (e.g., if SYP ever changes denomination and the project temporarily hides it).
- Using `SECURITY INVOKER` instead of `SECURITY DEFINER` — the function would then run with the caller's permissions; an admin who somehow bypassed RLS could also bypass this trigger. `SECURITY DEFINER` is the project-wide pattern (Phase 6, Phase 8).
