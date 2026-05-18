# Contract: Currencies Seed Inventory

**Owner**: Phase 9, migrations 1 + 2.
**Consumers**: every Phase 9 success criterion (SC-001 through SC-004); every user-facing surface that resolves `currency_code` to a display name.

## Obligations

### `public.currencies` — exactly 2 rows, both `is_system=true`

| code | name_ar | name_en | symbol | is_active | sort_order | display_decimals | is_system |
|---|---|---|---|---|---|---|---|
| `SYP` | `ليرة سورية` | `Syrian Pound` | `ل.س` | true | 10 | 0 | true |
| `USD` | `دولار أمريكي` | `US Dollar` | `$` | true | 20 | 2 | true |

Idempotency: `ON CONFLICT (code) DO NOTHING`. Re-running the migration produces zero new rows.

### `public.exchange_rates` — optional starter (FR-005 enacted at plan time per data-model.md)

| base_currency | target_currency | rate | effective_at | set_by | source |
|---|---|---|---|---|---|
| `USD` | `SYP` | `15000.000000` | migration timestamp | `NULL` | `'seed'` |
| `SYP` | `USD` | `0.000067` (= `round(1/15000, 6)`) | migration timestamp | `NULL` | `'auto-derived from seed (USD→SYP)'` |

Idempotency: `WHERE NOT EXISTS (SELECT 1 FROM public.exchange_rates WHERE base_currency='USD' AND target_currency='SYP')`. Re-running the migration produces zero new rows once the pair exists.

## Verification

```sql
-- Currency row count
SELECT count(*) FROM public.currencies;
-- Expected: 2

-- Currency row shape matches the contract
SELECT code, name_ar, name_en, symbol, is_active, sort_order, display_decimals, is_system
FROM public.currencies ORDER BY sort_order;
-- Expected: 2 rows exactly matching the table above

-- Exchange rate seed (if enacted)
SELECT count(*) FROM public.exchange_rates WHERE base_currency = 'USD' AND target_currency = 'SYP';
-- Expected: 1 (admin-direction seeded row)
SELECT count(*) FROM public.exchange_rates WHERE base_currency = 'SYP' AND target_currency = 'USD';
-- Expected: 1 (auto-derived inverse)

-- Seed audit rows
SELECT count(*) FROM public.audit_logs WHERE action = 'currency.created' AND actor_user_id IS NULL;
-- Expected: 2

SELECT count(*) FROM public.audit_logs WHERE action = 'exchange_rate.updated' AND actor_user_id IS NULL;
-- Expected: 2 (if FR-005 starter rate is enacted)
```

## Forbidden

- Seeding any currency without `is_system=true`. The two seeded rows are the project's foundational catalog and MUST be protected by the immutability trigger.
- Seeding a currency with empty `name_ar`, `name_en`, or `symbol` (the CHECK constraint enforces non-empty).
- Adding currencies beyond USD and SYP at seed time. Custom currencies (EUR, TRY, etc.) are added via the in-app admin form per US3.
- Seeding without the Q2 auto-derive contract — if the starter USD → SYP rate is seeded, the inverse SYP → USD MUST be seeded too.
