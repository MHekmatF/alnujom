# Contract: `Money` Domain Value Object

**Owner**: Phase 9 (`lib/shared/domain/value_objects/money.dart`).
**Consumers**: every price-rendering surface across the app — Phase 10 listing form, Phase 13 listing details + home grid, Phase 14 search results, Phase 15 map popovers, the Phase 9 `latest_rate_subline.dart` widget.
**Stability**: Field shape is stable for v1. Future additions are appends only (never renames or removals).

## Class shape

```dart
import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

class Money extends Equatable {
  final Decimal amount;
  final String currencyCode;  // 3-letter ISO-style code, matches public.currencies.code

  const Money({required this.amount, required this.currencyCode});

  @override
  List<Object?> get props => [amount, currencyCode];
}
```

## Obligations

1. **Immutable**: All fields `final`. No setter. Mutations via a hand-written `copyWith` if needed (not required for v1).
2. **Equatable**: Value equality via `Equatable.props`.
3. **Decimal amount**: The `amount` field is `Decimal` from `package:decimal` (R-03 / R-09). Phase 9 introduces the package; downstream features consume `Decimal` through this value object.
4. **3-letter currency code**: The `currencyCode` field is a `String` matching the ISO 4217-style 3-letter format that `public.currencies.code` enforces. The value object does NOT validate the format at construction (the database CHECK constraint is the canonical validator); but consumers SHOULD construct only via the Phase 9 mappers that resolve a `currency_code` from a `public.currencies` row.
5. **No `rate` field** (Q1 / SC-023). The value object does NOT carry an exchange rate. Phase 9's no-conversion stance is enforced at the type level.
6. **No `displayCurrency` field** (Q1 / SC-023). The value object represents one amount in one currency.

## Forbidden imports

The file MUST NOT import:

- `package:supabase_flutter/supabase_flutter.dart` (Constitution IX).
- `package:intl/intl.dart` (intl is a presentation concern; the value object is domain).
- Anything under `lib/data/` or `lib/features/<x>/data/`.
- Anything under `lib/features/<x>/presentation/` (would be a domain → presentation reverse dependency).

The file MAY import:

- `package:decimal/decimal.dart`.
- `package:equatable/equatable.dart`.

## Verification

```bash
# The file imports exactly the two allowed packages
head -10 lib/shared/domain/value_objects/money.dart
# Expected: imports are `package:decimal/decimal.dart` and `package:equatable/equatable.dart` only.

# No rate field in the public API
grep -E 'rate|convert|exchange' lib/shared/domain/value_objects/money.dart
# Expected: zero matches in any public field or method signature (SC-023)

# Dart analyzer passes
dart analyze lib/shared/domain/value_objects/money.dart
# Expected: zero issues
```

## Forbidden

- Adding any conversion-related method (`Money convertTo(...)`, `Money applyRate(Rate)`, etc.). Q1 forbids display-time conversion entirely in Phase 9.
- Adding mutability (a setter, a `copyWith` that recurses on amount). Value objects are immutable.
- Persisting the `Money` value object directly — there is no `public.money` table. `Money` is a domain-layer construct; Phase 10's `listing_prices` table stores `amount NUMERIC + currency_code TEXT` as separate columns, and the mapper composes them into `Money` at the data-layer boundary.
