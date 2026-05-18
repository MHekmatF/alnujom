# currencies

## Purpose

`currencies` stores the global currency catalog used by price-aware features. Phase 9 seeds `SYP` and `USD` as system rows.

## Columns

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `code` | `TEXT` | NO | - | Primary key; 3 uppercase ASCII letters. |
| `name_ar` | `TEXT` | NO | - | Arabic display name. |
| `name_en` | `TEXT` | NO | - | English display name. |
| `symbol` | `TEXT` | NO | - | Canonical display symbol. |
| `is_active` | `BOOLEAN` | NO | `true` | Soft-deactivation flag. |
| `sort_order` | `INTEGER` | NO | `100` | Editorial display order. |
| `is_system` | `BOOLEAN` | NO | `false` | Seed protection flag. |
| `display_decimals` | `SMALLINT` | NO | `2` | Formatting precision, constrained to 0-8. |
| `created_at` | `TIMESTAMPTZ` | NO | `now()` | Insert timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `now()` | Maintained by `set_updated_at`. |

## RLS posture

`currencies_select` allows `anon` and `authenticated` users to read all rows. Insert, update, and delete policies require `current_user_has_permission('currencies.manage')`.

## Immutability trigger

`enforce_currency_system_immutability` refuses DELETE and `code` rename attempts when `is_system=true`. Other editable columns remain mutable for admin correction.

## Audit triggers

The table emits these action keys via `log_audit()`:

| Event | Action key |
|---|---|
| INSERT | `currency.created` |
| UPDATE | `currency.updated` |
| DELETE | `currency.deleted` |

## Seed inventory

| code | name_ar | name_en | symbol | sort_order | display_decimals | is_system |
|---|---|---|---|---|---|---|
| `SYP` | `ليرة سورية` | `Syrian Pound` | `ل.س` | 10 | 0 | true |
| `USD` | `دولار أمريكي` | `US Dollar` | `$` | 20 | 2 | true |

## Notes

R-07 protects seeded system currencies from accidental destructive mutations. R-08 requires audit triggers to be attached before seed INSERTs so initial rows produce `currency.created` audit entries.
