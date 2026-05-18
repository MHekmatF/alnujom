# Contract: Phase 9 Audit Triggers

**Owner**: Phase 9, migrations 1 + 2.
**Consumers**: any reader of `public.audit_logs`; Phase 22 (push + Realtime) which subscribes to audit rows; compliance / regulatory queries.

## Obligations

Phase 9 attaches two audit-trigger groups, both invoking Phase 4's `log_audit()` PL/pgSQL function **unchanged** (R-05, sixth carry-forward).

### Group 1 — `public.currencies` (INSERT / UPDATE / DELETE)

Three triggers fire `AFTER INSERT`, `AFTER UPDATE`, `AFTER DELETE` for each row, calling:

- `log_audit('currency.created', 'currencies', 'code')`
- `log_audit('currency.updated', 'currencies', 'code')`
- `log_audit('currency.deleted', 'currencies', 'code')`

The third argument (`'code'`) tells `log_audit` which column to read as `target_id`. The function uses `NEW.code` for INSERT/UPDATE and `OLD.code` for DELETE.

### Group 2 — `public.exchange_rates` (INSERT only)

One trigger fires `AFTER INSERT` for each row, calling:

- `log_audit('exchange_rate.updated', 'exchange_rates', 'id')`

There is **no** `exchange_rate.updated` UPDATE trigger and **no** `exchange_rate.deleted` DELETE trigger — UPDATE and DELETE are blocked by RLS (R-08), so those verbs cannot fire.

The action key is `exchange_rate.updated` (not `.created`) because the user-perceived intent of every INSERT is "the rate has been updated" — even though the table mechanically appends a new row. This matches the implementation plan §9.4 wording.

### Ordering invariant (R-08)

In each migration, the audit triggers MUST be attached **before** the seed `INSERT` statements run. Every seeded row produces exactly one corresponding audit row with `actor_user_id=NULL`.

## Verification

```sql
-- Triggers exist on currencies
SELECT trigger_name, event_manipulation FROM information_schema.triggers
WHERE event_object_schema='public' AND event_object_table='currencies'
  AND trigger_name LIKE 'audit_currencies_%'
ORDER BY trigger_name;
-- Expected: 3 rows (audit_currencies_insert/update/delete)

-- Trigger exists on exchange_rates
SELECT trigger_name, event_manipulation FROM information_schema.triggers
WHERE event_object_schema='public' AND event_object_table='exchange_rates'
  AND trigger_name = 'audit_exchange_rates_insert';
-- Expected: 1 row

-- Seed audit rows exist with NULL actor_user_id
SELECT action, count(*) FROM public.audit_logs
WHERE actor_user_id IS NULL AND target_type IN ('currencies', 'exchange_rates')
GROUP BY action ORDER BY action;
-- Expected: 'currency.created' = 2 (USD + SYP), and if FR-005 seed is enacted, 'exchange_rate.updated' = 2 (admin + derived)
```

## Forbidden

- Modifying `log_audit()`. Phase 9 reuses it strictly as-is.
- Adding extra triggers that fire on the same verbs (would emit duplicate audit rows; SC-015 / FR-026 require one-per-row).
- Skipping the audit trigger on the optional starter rate seed (the rows MUST emit their audit row even though `actor_user_id` is NULL).
