# Data Model: Currencies & Exchange Rates

**Owner**: Phase 9 (`specs/009-currencies/`).
**Created**: 2026-05-17
**Status**: Locked. Authoritative input to the five Phase 9 migrations + the new feature folder under `lib/features/currencies/`.

This document captures the exact column shapes, constraints, indexes, RLS policies, triggers, and BLoC + entity shapes that the implementation MUST produce. Anything not specified here is a plan-time deferral noted in `checklists/requirements.md`.

---

## Tables

### `public.currencies`

```sql
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

-- Phase 4 helper: keep updated_at fresh on every UPDATE
DROP TRIGGER IF EXISTS set_currencies_updated_at ON public.currencies;
CREATE TRIGGER set_currencies_updated_at
  BEFORE UPDATE ON public.currencies
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

**Notes**:
- `code` is the primary key — 3 uppercase ASCII letters (ISO 4217-style).
- `name_ar` / `name_en` are parallel TEXT columns (not a single JSONB) per implementation plan §6.2 prescription; R-18 fallback chain reads either column.
- `symbol` is the canonical display glyph for the currency (`'$'`, `'ل.س'`, `'€'`). `MoneyFormatter` reads this at format time per R-12.
- `display_decimals` is the per-currency rounding rule consumed by `MoneyFormatter` per R-09/R-22; SYP = 0, USD = 2.
- `sort_order` is the editorial display order; lower values appear first. SYP = 10, USD = 20 per the seed.

### `public.exchange_rates`

```sql
CREATE TABLE IF NOT EXISTS public.exchange_rates (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  base_currency   TEXT        NOT NULL REFERENCES public.currencies(code) ON DELETE RESTRICT,
  target_currency TEXT        NOT NULL REFERENCES public.currencies(code) ON DELETE RESTRICT,
  rate            NUMERIC(18, 6) NOT NULL CHECK (rate > 0),
  effective_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  set_by          UUID                 REFERENCES auth.users(id)         ON DELETE SET NULL,
  source          TEXT                                                   CHECK (source IS NULL OR length(source) <= 500),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT exchange_rates_base_neq_target CHECK (base_currency <> target_currency)
);

ALTER TABLE public.exchange_rates ENABLE ROW LEVEL SECURITY;

-- Composite index for the latest-rate-per-pair lookup query path
CREATE INDEX IF NOT EXISTS idx_exchange_rates_base_target_effective
  ON public.exchange_rates (base_currency, target_currency, effective_at DESC);
```

**Notes**:
- The table is **append-only by RLS** (FR-008) — UPDATE and DELETE policies do not exist, so no row is ever mutated post-INSERT.
- `set_by` is `NULL` for system-INSERTed rows (the seed, if FR-005 is enacted at plan time). For all admin-authored or auto-derived rows, `set_by = auth.uid()`.
- `source` is admin-authored free text (≤ 500 chars) OR the auto-derive marker `'auto-derived from <admin_row_uuid>'` per R-06 / Q2.
- The composite index supports the FR-014 latest-rate-lookup `SELECT rate FROM exchange_rates WHERE base_currency=$1 AND target_currency=$2 AND effective_at <= now() ORDER BY effective_at DESC LIMIT 1`.

---

## Triggers

### Audit triggers (2 groups) — reuse Phase 4 `log_audit()` unchanged

```sql
-- currencies: INSERT / UPDATE / DELETE → currency.created / .updated / .deleted
DROP TRIGGER IF EXISTS audit_currencies_insert ON public.currencies;
DROP TRIGGER IF EXISTS audit_currencies_update ON public.currencies;
DROP TRIGGER IF EXISTS audit_currencies_delete ON public.currencies;

CREATE TRIGGER audit_currencies_insert
  AFTER INSERT ON public.currencies
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('currency.created', 'currencies', 'code');

CREATE TRIGGER audit_currencies_update
  AFTER UPDATE ON public.currencies
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('currency.updated', 'currencies', 'code');

CREATE TRIGGER audit_currencies_delete
  AFTER DELETE ON public.currencies
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('currency.deleted', 'currencies', 'code');

-- exchange_rates: INSERT only → exchange_rate.updated
-- (UPDATE and DELETE are blocked by RLS, so no triggers needed for those verbs)
DROP TRIGGER IF EXISTS audit_exchange_rates_insert ON public.exchange_rates;

CREATE TRIGGER audit_exchange_rates_insert
  AFTER INSERT ON public.exchange_rates
  FOR EACH ROW EXECUTE FUNCTION public.log_audit('exchange_rate.updated', 'exchange_rates', 'id');
```

**Ordering invariant (R-08)**: These triggers MUST be attached BEFORE any seed `INSERT` in the same migration. The seed produces 2 `currency.created` audit rows (and optionally 2 `exchange_rate.updated` rows if FR-005 starter is enacted) with `actor_user_id=NULL`.

### Immutability trigger (1) — new in Phase 9, mirrors Phase 6/8 precedent

```sql
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
    RAISE EXCEPTION 'cannot rename system currency code (% → %)', OLD.code, NEW.code
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
```

**Notes**:
- Fires `BEFORE` so the row is rejected before any audit trigger fires for an illegal DELETE/UPDATE.
- `SECURITY DEFINER + search_path=public` mirrors Phase 6's `enforce_role_system_immutability` and Phase 8's two location immutability triggers (R-07).
- Errors with SQLSTATE `42501` (insufficient_privilege) — the Flutter client maps to a localized "system currency cannot be renamed or deleted" error per FR-024.
- Only refuses DELETE and `code`-rename. Other column updates on `is_system=true` rows (e.g., changing `display_decimals` from 2 to 0) are allowed.

---

## RLS policies

### `public.currencies`

```sql
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
```

### `public.exchange_rates`

```sql
-- SELECT: public read (anon + authenticated)
DROP POLICY IF EXISTS exchange_rates_select ON public.exchange_rates;
CREATE POLICY exchange_rates_select ON public.exchange_rates
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT: currencies.manage holders only (NO UPDATE policy, NO DELETE policy — append-only)
DROP POLICY IF EXISTS exchange_rates_insert ON public.exchange_rates;
CREATE POLICY exchange_rates_insert ON public.exchange_rates
  FOR INSERT
  TO authenticated
  WITH CHECK (public.current_user_has_permission('currencies.manage'));

-- Explicit deny on UPDATE and DELETE for defense-in-depth (optional but recommended)
-- Postgres RLS defaults to deny when no matching policy exists; these explicit
-- deny-policies make the append-only invariant unambiguous to any future reader.
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
```

---

## `update_exchange_rate` RPC

```sql
CREATE OR REPLACE FUNCTION public.update_exchange_rate(
  p_base_currency   TEXT,
  p_target_currency TEXT,
  p_rate            NUMERIC,
  p_effective_at    TIMESTAMPTZ DEFAULT now(),
  p_source          TEXT        DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_admin_row     public.exchange_rates%ROWTYPE;
  v_derived_row   public.exchange_rates%ROWTYPE;
  v_derived_rate  NUMERIC(18, 6);
BEGIN
  -- (a) Permission check (re-checked even though RLS will also deny non-holders)
  IF NOT public.current_user_has_permission('currencies.manage') THEN
    RAISE EXCEPTION 'permission denied: currencies.manage required'
      USING ERRCODE = '42501';
  END IF;

  -- (b) Input validation
  IF p_base_currency = p_target_currency THEN
    RAISE EXCEPTION 'base_currency and target_currency must differ'
      USING ERRCODE = '22023';
  END IF;

  IF p_rate <= 0 THEN
    RAISE EXCEPTION 'rate must be positive (got %)', p_rate
      USING ERRCODE = '22023';
  END IF;

  -- The FK constraints on base_currency/target_currency will reject unknown codes
  -- The CHECK constraint will reject p_rate <= 0 even if we didn't catch it
  -- This pre-validation produces nicer error messages

  -- (c) Compute the auto-derived inverse rate (R-11 banker's rounding to 6 decimals)
  -- Postgres NUMERIC division: (1.0 / p_rate) preserves precision; the round() applies banker's rounding by default for half-cases at the requested scale
  v_derived_rate := round(1.0 / p_rate, 6);

  -- (d) INSERT admin-authored row
  INSERT INTO public.exchange_rates (base_currency, target_currency, rate, effective_at, set_by, source)
  VALUES (p_base_currency, p_target_currency, p_rate, p_effective_at, auth.uid(), p_source)
  RETURNING * INTO v_admin_row;

  -- (e) INSERT auto-derived inverse row (R-06 / Q2)
  INSERT INTO public.exchange_rates (base_currency, target_currency, rate, effective_at, set_by, source)
  VALUES (p_target_currency, p_base_currency, v_derived_rate, p_effective_at, auth.uid(),
          format('auto-derived from %s', v_admin_row.id))
  RETURNING * INTO v_derived_row;

  -- (f) Return both rows
  RETURN jsonb_build_object(
    'admin_row',   to_jsonb(v_admin_row),
    'derived_row', to_jsonb(v_derived_row)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_exchange_rate(TEXT, TEXT, NUMERIC, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_exchange_rate(TEXT, TEXT, NUMERIC, TIMESTAMPTZ, TEXT) TO authenticated;
```

**Notes**:
- The function's transactional scope is implicit — both INSERTs commit together or both roll back (atomicity from R-06 / Q2).
- The audit triggers from `exchange_rates` fire once per INSERT, so this RPC produces exactly 2 `exchange_rate.updated` audit rows per call (US8 acceptance scenario 4).
- The SQLSTATE error codes (`42501`, `22023`) map to user-facing errors per FR-024.

---

## Seed inventory

### `public.currencies` (2 rows, both `is_system=true`)

| code | name_ar | name_en | symbol | is_active | sort_order | display_decimals | is_system |
|---|---|---|---|---|---|---|---|
| `SYP` | `ليرة سورية` | `Syrian Pound` | `ل.س` | true | 10 | 0 | true |
| `USD` | `دولار أمريكي` | `US Dollar` | `$` | true | 20 | 2 | true |

```sql
INSERT INTO public.currencies (code, name_ar, name_en, symbol, is_active, sort_order, display_decimals, is_system) VALUES
  ('SYP', 'ليرة سورية',    'Syrian Pound', 'ل.س', true, 10, 0, true),
  ('USD', 'دولار أمريكي',  'US Dollar',    '$',   true, 20, 2, true)
ON CONFLICT (code) DO NOTHING;
```

### `public.exchange_rates` (optional FR-005 starter — plan-time decision is **SEED** for development convenience)

| base | target | rate | effective_at | set_by | source |
|---|---|---|---|---|---|
| `USD` | `SYP` | `15000.000000` | migration timestamp | `NULL` | `'seed'` |
| `SYP` | `USD` | `0.000067` | migration timestamp | `NULL` | `'auto-derived from seed (USD→SYP)'` |

```sql
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.exchange_rates WHERE base_currency = 'USD' AND target_currency = 'SYP') THEN
    INSERT INTO public.exchange_rates (base_currency, target_currency, rate, effective_at, set_by, source) VALUES
      ('USD', 'SYP', 15000.000000, now(), NULL, 'seed'),
      ('SYP', 'USD', round(1.0 / 15000.000000, 6), now(), NULL, 'auto-derived from seed (USD→SYP)');
  END IF;
END $$;
```

**Notes**:
- The starter rate of 15,000 SYP per USD reflects a realistic mid-2026 Syrian market rate for development. Real production rates are admin-managed via US3 after deploy.
- Idempotency guarded by `WHERE NOT EXISTS` on the pair — re-running the migration does not duplicate.
- Both rows seeded with `set_by=NULL` (system provenance).
- Both audit rows produced by these INSERTs carry `actor_user_id=NULL`.

---

## Existing tables altered

### `public.user_preferences` — add FK on `display_currency`

```sql
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_preferences_display_currency_fkey'
  ) THEN
    ALTER TABLE public.user_preferences
      ADD CONSTRAINT user_preferences_display_currency_fkey
      FOREIGN KEY (display_currency)
      REFERENCES public.currencies(code)
      ON DELETE SET NULL;
  END IF;
END $$;
```

**Notes**:
- MUST run AFTER the `currencies` seed migration (R-14).
- Idempotent via the `pg_constraint` check.
- The existing default value `'SYP'` (per Phase 4) already satisfies the FK because the seed has run by the time this migration applies.
- `ON DELETE SET NULL` so the FK doesn't block a future custom-currency deletion (system rows USD/SYP are protected by the immutability trigger anyway).

---

## Flutter feature folder shapes

### `lib/shared/domain/value_objects/money.dart`

```dart
import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

class Money extends Equatable {
  final Decimal amount;
  final String currencyCode;  // ISO 4217-style 3-letter code

  const Money({required this.amount, required this.currencyCode});

  @override
  List<Object?> get props => [amount, currencyCode];
}
```

**Notes**:
- NO `rate` field (Q1 / SC-023).
- NO `displayCurrency` field — the formatter takes the locale + currency lookup separately.
- Immutable; equality via `Equatable.props`.

### `lib/shared/presentation/money_formatter.dart`

```dart
import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/intl.dart' as intl;

import '../domain/value_objects/money.dart';
import '../../features/currencies/domain/entities/currency.dart';

class MoneyFormatter {
  /// Formats [money] using the currency's display decimals and locale-appropriate
  /// digit form, separator, and symbol position.
  ///
  /// Per R-22, when [money.currencyCode] doesn't match any active currency, the
  /// formatter renders the amount with the bare currency code as a fallback symbol.
  ///
  /// Per Q1 / SC-023, this function does NOT accept a rate parameter and does NOT
  /// multiply by anything — display-time currency conversion is not part of Phase 9.
  static String format(
    Money money, {
    required Locale locale,
    required Currency currency,
  }) {
    // ... (implementation details — see contracts/money-formatter.md for spec)
  }
}
```

**Notes**:
- NO `rate` parameter (Q1 / SC-023).
- The `currency` argument carries the symbol + `display_decimals` rule.
- Returns a `String`, not a `Widget` — design-token consumption is the caller's responsibility.

### `lib/features/currencies/domain/entities/currency.dart`

```dart
import 'package:equatable/equatable.dart';

class Currency extends Equatable {
  final String code;             // PRIMARY KEY
  final String nameAr;
  final String nameEn;
  final String symbol;
  final bool isActive;
  final int sortOrder;
  final bool isSystem;
  final int displayDecimals;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Currency({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.symbol,
    required this.isActive,
    required this.sortOrder,
    required this.isSystem,
    required this.displayDecimals,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Per R-18, returns the active-locale name or falls back through other locale → code.
  String localizedName(Locale locale) {
    final value = locale.languageCode == 'ar' ? nameAr : nameEn;
    if (value.isNotEmpty) return value;
    final fallback = locale.languageCode == 'ar' ? nameEn : nameAr;
    return fallback.isNotEmpty ? fallback : code;
  }

  @override
  List<Object?> get props => [code, nameAr, nameEn, symbol, isActive, sortOrder, isSystem, displayDecimals, createdAt, updatedAt];
}
```

### `lib/features/currencies/domain/entities/exchange_rate.dart`

```dart
import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

class ExchangeRate extends Equatable {
  final String id;
  final String baseCurrency;
  final String targetCurrency;
  final Decimal rate;
  final DateTime effectiveAt;
  final String? setBy;           // auth.users.id, nullable for system rows
  final String? source;
  final DateTime createdAt;

  const ExchangeRate({
    required this.id,
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.effectiveAt,
    required this.setBy,
    required this.source,
    required this.createdAt,
  });

  /// True iff this row was server-auto-derived (R-06 / Q2).
  bool get isDerived => source?.startsWith('auto-derived from ') ?? false;

  @override
  List<Object?> get props => [id, baseCurrency, targetCurrency, rate, effectiveAt, setBy, source, createdAt];
}
```

### `lib/features/currencies/domain/entities/update_exchange_rate_result.dart`

```dart
import 'package:equatable/equatable.dart';

import 'exchange_rate.dart';

class UpdateExchangeRateResult extends Equatable {
  final ExchangeRate adminRow;
  final ExchangeRate derivedRow;

  const UpdateExchangeRateResult({
    required this.adminRow,
    required this.derivedRow,
  });

  @override
  List<Object?> get props => [adminRow, derivedRow];
}
```

### Repository interface

```dart
abstract class CurrenciesRepository {
  Future<List<Currency>> listCurrencies({bool activeOnly = false});
  Future<Currency> loadCurrency(String code);
  Future<Currency> createCurrency({ /* fields */ });
  Future<Currency> updateCurrency(Currency updated);
  Future<void> deleteCurrency(String code);

  Future<List<ExchangeRate>> listExchangeRateHistory({
    required String baseCurrency,
    String? targetCurrencyFilter,
    int limit = 50,
    DateTime? cursorBefore,
  });

  Future<Map<String, Decimal>> loadLatestRatesForBase(String baseCurrency);
  Future<UpdateExchangeRateResult> setExchangeRate({
    required String baseCurrency,
    required String targetCurrency,
    required Decimal rate,
    required DateTime effectiveAt,
    String? source,
  });

  Future<String?> readUserDisplayCurrency();
  Future<void> writeUserDisplayCurrency(String code);
}
```

### BLoC shapes

| BLoC | States | Key Events |
|---|---|---|
| `CurrenciesListBloc` | `Initial / Loading / Loaded(List<CurrencyWithLatestRates>) / Error(message)` | `LoadCurrencies`, `RefreshCurrencies`, `CurrencyMutated(code)` |
| `CurrencyFormBloc` | `Idle / Validating / Saving / SaveSuccess(Currency) / SaveFailure(reason)` | `EditFieldChanged(name, value)`, `SubmitPressed`, `LoadForEdit(code)` |
| `SetExchangeRateBloc` | `Idle / DerivedRatePreview(Decimal previewInverse) / Saving / SaveSuccess(UpdateExchangeRateResult) / SaveFailure(reason) / UnusualTimingPending(action)` | `BaseChanged`, `TargetChanged`, `RateChanged`, `EffectiveAtChanged`, `SourceChanged`, `SubmitPressed`, `UnusualTimingConfirmed`, `UnusualTimingCancelled` |
| `ExchangeRateHistoryBloc` | `Initial / Loading / Loaded(List<ExchangeRate>, hasMore) / LoadingMore / Error(message)` | `LoadHistory(baseCurrency, targetFilter)`, `LoadMore`, `TargetFilterChanged(target?)` |

---

## ARB key inventory

The Phase 9 ARB-key delta is approximately 25 keys per locale (50 keys total across `app_ar.arb` and `app_en.arb`). The categories:

| Category | Keys (approx) | Examples |
|---|---|---|
| Admin page titles | 4 | `currenciesPageTitle`, `setExchangeRatePageTitle`, `exchangeRateHistoryPageTitle`, `currencyFormPageTitle` |
| Tile labels | 1 | `adminHomeCurrenciesTile` |
| Button labels | 5 | `addCurrencyButton`, `setNewRateButton`, `viewHistoryButton`, `deactivateButton`, `confirmButton` |
| Form field labels | 6 | `currencyCodeLabel`, `currencyNameArLabel`, `currencyNameEnLabel`, `currencySymbolLabel`, `currencySortOrderLabel`, `currencyDisplayDecimalsLabel`, `rateAmountLabel`, `effectiveAtLabel`, `sourceLabel`, `preferredCurrencyLabel` |
| Validation messages | 4 | `currencyCodeFormatError`, `rateMustBePositiveError`, `baseEqualsTargetError`, `displayDecimalsRangeError` |
| Dialog copy | 3 | `deleteCurrencyConfirmTitle` (+ body template), `unusualTimingFutureTitle` (+ body), `unusualTimingBackdateTitle` (+ body — distinct copy per FR-017 Q5 wording) |
| Structured-error strings | 3 | `errorSystemCurrencyImmutable`, `errorCurrencyHasReferences`, `errorPermissionDenied` |
| Misc UI | 3 | `derivedBadgeLabel`, `rateNotAvailableHint`, `latestRateLineTemplate` (parameterized for "1 {base} = {amount} {target}") |

All keys ship to both `app_ar.arb` and `app_en.arb` in the same commit. The Phase 3 localization lint guard catches missing translations at PR review.

---

## Per-FR / per-SC verification mapping

| Requirement | Verification path | Owning artifact |
|---|---|---|
| FR-001/002 (currencies schema) | SQL: `\d+ public.currencies` shows all columns + RLS enabled | `data-model.md` + migration 1 |
| FR-003 (exchange_rates schema) | SQL: `\d+ public.exchange_rates` shows all columns + composite index | `data-model.md` + migration 2 |
| FR-004 (seed of USD + SYP) | SQL: `SELECT code FROM currencies ORDER BY sort_order` returns SYP, USD | migration 1 |
| FR-005 (optional starter rate) | SQL: `SELECT count(*) FROM exchange_rates` returns 0 or 2 | migration 2 |
| FR-006 (FK shape) | SQL: query `information_schema.referential_constraints` | migrations 1, 2, 4 |
| FR-007 (audit triggers) | Direct-SQL test: INSERT a currency, observe `currency.created` audit row | migrations 1, 2 |
| FR-007a (immutability trigger) | Direct-SQL test: DELETE USD → `42501` error | migration 1 |
| FR-008 (RLS posture) | Direct-SQL test: anonymous client SELECT works; INSERT denied | migrations 1, 2 |
| FR-009 (anon SELECT) | As above | migrations 1, 2 |
| FR-010 (no new permission keys) | grep `lib/core/security/permission_keys.dart` — `currenciesManage` exists from Phase 6, nothing new added | (no change) |
| FR-011 (PermissionChecker cache refresh) | UI flow: revoke `currencies.manage` mid-session, foreground app, tile disappears | (no code change — Phase 6 invariant) |
| FR-012 (update_exchange_rate RPC) | Call RPC from device, verify two rows inserted with correct shapes | migration 3 |
| FR-013 (admin tile) | UI flow: admin sees tile; non-admin doesn't | `admin_home_page.dart` edit |
| FR-014 (route guard) | UI flow: deep-link from moderator session → unauthorized redirect | `auth_redirect.dart` edit |
| FR-015 (admin pages) | UI flow: navigate through all four pages | `lib/features/currencies/presentation/pages/*` |
| FR-015a (system-row affordance hiding) | UI flow: open USD row → no Delete affordance | `currency_card.dart` |
| FR-016 (form validation + derived-rate preview) | UI flow: enter base=target → error; enter rate=15000 → preview shows 1/15000 | `set_exchange_rate_bloc.dart` + page |
| FR-017 (symmetric 24h gate) | UI flow: future-date by 48h → dialog; backdate by 48h → dialog (different copy) | `unusual_timing_confirmation_dialog.dart` |
| FR-018 (preferred-currency toggle) | UI flow: profile page → toggle → DB row updated | `preferred_currency_toggle.dart` |
| FR-019 (user_preferences FK) | SQL: `SELECT conname FROM pg_constraint WHERE conname='user_preferences_display_currency_fkey'` | migration 4 |
| FR-019a (row-selection rule) | Once Phase 10 ships, exercise multi-currency listing | `select_listing_price_row.dart` |
| FR-020 (Money value object) | Dart analyzer: `Money` class has no `rate` field | `money.dart` |
| FR-021 (formatter renders RTL Arabic digits) | UI flow: 10 golden cases on `MoneyFormatterShowcasePage` | `money_formatter.dart` |
| FR-022 (formatter doesn't inject hint) | Code review: formatter returns String only, no hint | `money_formatter.dart` |
| FR-023 (formatter rounds + handles zero/negative) | UI flow: golden cases include zero + negative cases | `money_formatter.dart` |
| FR-024 (ARB keys) | grep `app_ar.arb` and `app_en.arb` for the ~25 new keys | `app_ar.arb`, `app_en.arb` |
| FR-025 (design tokens) | Code review: no inline hex/font-size/padding under `lib/features/currencies/` | (review) |
| FR-026 (audit row counts) | Direct-SQL test: 1 row per `currency.*`, 2 rows per `update_exchange_rate` call | migration 1, 2, 3 |
| SC-001 (seed count) | SQL: `SELECT count(*) FROM currencies` = 2 | migration 1 |
| SC-005 (admin journey ≤ 60s) | Stopwatched UI flow on Infinix Note 8 | quickstart.md |
| SC-008 (no exchange_rates UPDATE possible) | Direct-SQL test: UPDATE → 0 rows affected | migrations 1, 2 |
| SC-008a (2 rows per RPC call) | Direct-SQL: count rows before/after RPC = +2 | migration 3 |
| SC-022 (FK exists post-deploy) | SQL: `information_schema.referential_constraints` | migration 4 |
| SC-023 (formatter API has no rate) | grep `money_formatter.dart` for `rate|convert|exchange` returns 0 in public signatures | (review) |
| SC-024 (UNIQUE on listing_prices) | Forward-stated; verified at Phase 10 ship time | (Phase 10) |
| SC-025 (symmetric gate dialog) | UI flow: future-date by 48h → dialog; backdate by 48h → dialog | quickstart.md |

The remaining SCs (002, 003, 004, 006, 007, 009, 010, 011, 012, 013, 014, 015, 016, 017, 018, 019, 020, 021) are each spelled out in `quickstart.md`.
