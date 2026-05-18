# exchange_rates

## Purpose

`exchange_rates` stores append-only exchange-rate history between currencies. Phase 9 seeds an optional starter USD to SYP rate and its auto-derived inverse.

## Columns

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `UUID` | NO | `gen_random_uuid()` | Primary key. |
| `base_currency` | `TEXT` | NO | - | FK to `currencies(code)`, `ON DELETE RESTRICT`. |
| `target_currency` | `TEXT` | NO | - | FK to `currencies(code)`, `ON DELETE RESTRICT`. |
| `rate` | `NUMERIC(18, 6)` | NO | - | Positive rate. |
| `effective_at` | `TIMESTAMPTZ` | NO | `now()` | Rate effective timestamp. |
| `set_by` | `UUID` | YES | `NULL` | FK to `auth.users(id)`, NULL for seed/system rows. |
| `source` | `TEXT` | YES | `NULL` | Admin note or auto-derive marker, max 500 chars. |
| `created_at` | `TIMESTAMPTZ` | NO | `now()` | Insert timestamp. |

## Append-only invariant

FR-008 makes `exchange_rates` append-only. UPDATE and DELETE policies are explicit `USING (false)`, and the canonical write path for admin rate changes is the `update_exchange_rate` RPC.

## RLS posture

`exchange_rates_select` allows `anon` and `authenticated` users to read history. INSERT is gated by `current_user_has_permission('currencies.manage')`.

## Composite index

`idx_exchange_rates_base_target_effective` covers `(base_currency, target_currency, effective_at DESC)` for latest-rate-per-pair lookups.

## Audit trigger

INSERT emits `exchange_rate.updated` via `log_audit()`. No UPDATE or DELETE audit trigger exists because those operations are blocked by RLS.

## Q2 auto-derive contract

Every admin call to `update_exchange_rate` produces two rows: the admin-authored row and an inverse row with `source='auto-derived from <uuid>'` where `<uuid>` is the admin row id.

## Seed inventory

| base_currency | target_currency | rate | set_by | source |
|---|---|---:|---|---|
| `USD` | `SYP` | `15000.000000` | `NULL` | `seed` |
| `SYP` | `USD` | `0.000067` | `NULL` | `auto-derived from seed (USD→SYP)` |

## Notes

R-08 requires trigger-before-seed ordering so seed rows produce audit entries. R-10 fixes rate precision at `NUMERIC(18,6)`. R-11 requires banker's rounding for future auto-derived rates.
