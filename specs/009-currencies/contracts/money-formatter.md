# Contract: `MoneyFormatter`

**Owner**: Phase 9 (`lib/shared/presentation/money_formatter.dart`).
**Consumers**: every price-rendering widget. The 10 plan-time-locked golden cases live in [quickstart.md § MoneyFormatter golden cases](../quickstart.md).
**Stability**: Public API is stable for v1. No conversion-related parameter may be added (SC-023).

## Class shape

```dart
class MoneyFormatter {
  /// Formats [money] for display, applying the currency's display_decimals rule
  /// and the locale's digit form, separator, and symbol position.
  ///
  /// Per Q1 / SC-023, this function does NOT accept a rate parameter and does
  /// NOT multiply by anything — display-time currency conversion is not part of
  /// Phase 9. The returned string represents the input amount in its native
  /// currency.
  static String format(
    Money money, {
    required Locale locale,
    required Currency currency,
  });
}
```

## Obligations

1. **Deterministic**: Same inputs produce byte-identical output across consecutive calls (SC-013). No hidden state, no I/O, no `DateTime.now()` reads, no random.

2. **No `rate` parameter** (SC-023). The function signature contains NO `rate`, NO `displayCurrency`, NO `convert`-prefixed method.

3. **Currency-driven rounding (R-09 / FR-022)**: The function rounds `money.amount` to `currency.displayDecimals` fractional digits using banker's rounding (half-to-even). The underlying `Money` value object is unchanged — only the display string reflects the rounded value.

4. **Locale-driven digit form**:
   - `locale.languageCode == 'ar'`: Arabic-Indic digits (`٠١٢٣٤٥٦٧٨٩`), Arabic thousands separator (`٬`, U+066C).
   - `locale.languageCode == 'en'`: ASCII Latin digits (`0123456789`), ASCII comma separator (`,`).

5. **Symbol-position rule (R-12 / FR-021)**:
   - In `ar` locale: **all currency symbols** (Latin like `$` or Arabic like `ل.س`) are placed AFTER the amount with a space separator (`٥٠٬٠٠٠ $`). This matches Arabic typographic convention regardless of the symbol's original-language convention.
   - In `en` locale: USD `$` is prefix (`$50,000`); SYP renders as the **ASCII code `SYP`** (NOT `ل.س`) in suffix position (`50,000 SYP`) — per Assumption 7, the Arabic glyph is inappropriate in an English UI context.
   - Future currencies (EUR, TRY, etc.): default to suffix-with-symbol in `ar`; in `en`, follow conventional symbol position based on `currency.symbol`'s character class (Latin symbol → prefix; non-Latin symbol → suffix code).

6. **ICU `ل.س` symbol override (R-12)**: ICU's default `ar` locale data renders SYP as `'SYP'`, not `'ل.س'`. The formatter overrides the symbol at format time by reading `currency.symbol` from the `Currency` argument. The override is currency-aware (USD keeps `$`).

7. **Zero amounts**: `{amount: 0, currency: SYP}` renders as `'٠ ل.س'` (ar) or `'0 SYP'` (en) — never blank (FR-023).

8. **Negative amounts** (admin contexts only): The minus sign is placed in the locale-appropriate position. In `ar` locale, the minus precedes the amount (`'-٥٠ ل.س'`). In `en` locale, the minus precedes the amount or the `$` symbol (`'-$50'` or `'$-50'` — implementation chooses one consistently).

9. **Performance**: Each `format(...)` call completes in under 10ms on the reference Infinix Note 8 (no I/O; pure-Dart `NumberFormat` instantiation per call is acceptable at MVP scale).

## Internal implementation (informative — not normative)

```dart
import 'package:intl/intl.dart' as intl;

static String format(Money money, {required Locale locale, required Currency currency}) {
  final localeTag = locale.toLanguageTag();  // 'ar' or 'en'
  final formatter = intl.NumberFormat.currency(
    locale: localeTag,
    symbol: _resolveSymbol(currency, locale),
    decimalDigits: currency.displayDecimals,
    // ... custom pattern for symbol position per FR-021
  );
  return formatter.format(money.amount.toDouble());  // or use Decimal-aware path if intl supports it
}

static String _resolveSymbol(Currency currency, Locale locale) {
  if (locale.languageCode == 'en' && currency.code == 'SYP') return 'SYP';  // R-12 ASCII fallback
  return currency.symbol;
}
```

(The actual implementation may differ; the contract is the input → output mapping captured by the golden cases in `quickstart.md`.)

## Verification

The 10 golden cases (see `quickstart.md`) — manually exercised on `MoneyFormatterShowcasePage` (R-21).

```bash
# Public API surface check
grep -E '(\s+|\b)rate(\s+|\b)|convert|exchange' lib/shared/presentation/money_formatter.dart
# Expected: zero matches in public method signatures (SC-023)

# Dart analyzer passes
dart analyze lib/shared/presentation/money_formatter.dart
# Expected: zero issues
```

## Forbidden imports

The file MAY import:

- `package:intl/intl.dart` (presentation-layer formatter; allowed since the file lives under `lib/shared/presentation/`).
- `package:flutter/widgets.dart` (for `Locale`).
- The two new `lib/shared/domain/value_objects/money.dart` and `lib/features/currencies/domain/entities/currency.dart` domain types.

The file MUST NOT import:

- `package:supabase_flutter/supabase_flutter.dart`.
- Anything under `lib/data/` or `lib/features/<x>/data/`.

## Forbidden behaviors

- Reading the rate from anywhere. The formatter operates on the input amount in the input currency.
- Mutating the `Money` argument.
- Caching `NumberFormat` instances in a global static (R-17 "no global state"). Per-call instantiation is fine at MVP scale.
- Returning a `Widget`. The function returns `String`; the calling widget owns the styling and design-token consumption.
