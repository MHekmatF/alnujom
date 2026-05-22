# Contract: Validators (`lib/core/validators/`)

**Owner**: Phase 10.
**Consumers**: the listing form's relevant step widgets; future Phase 14 search-filter inputs (forward-stated); future post-MVP forms.

## Obligations

Three new validators ship under `lib/core/validators/`, each a pure-Dart static function with no Supabase dependency. Each accepts the field value + an `AppLocalizations` instance (for localized error strings) and returns `null` on pass or a localized error string on failure.

### `AreaSizeValidator`

```dart
class AreaSizeValidator {
  static String? validate(num? value, AppLocalizations l10n);
}
```

Rules:
- `null` or `0` → `l10n.validatorAreaSizePositive`
- negative → `l10n.validatorAreaSizePositive`
- `> 999999` → `l10n.validatorAreaSizeTooLarge` (hard block)
- `> 5000` AND `≤ 999999` → returns null (pass) but the form widget may surface a soft warning hint (NOT a blocker)
- otherwise → `null` (pass)

### `PriceValidator`

```dart
class PriceValidator {
  static String? validate(Decimal? value, Currency currency, AppLocalizations l10n);
}
```

Rules:
- `null` → `l10n.validatorPricePositive`
- `<= 0` → `l10n.validatorPricePositive`
- precision exceeds `NUMERIC(14, 2)` (more than 12 integer digits or more than 2 fractional digits) → `l10n.validatorPriceTooPrecise`
- fractional-digit count exceeds the row's `currency.displayDecimals` (SYP=0, USD=2) → soft round-and-accept (the formatter handles display rounding; the stored value may be rounded down to currency precision before save — implementation choice deferred to the BLoC)
- otherwise → `null` (pass)

### `PhoneValidator`

```dart
class PhoneValidator {
  static ({String? error, String? normalized}) validateAndNormalize(String? value, AppLocalizations l10n);
}
```

Rules:
- `null` or empty after trim → `(error: l10n.validatorPhoneInvalid, normalized: null)`
- length after trim < 6 digits → `(error: l10n.validatorPhoneTooShort, normalized: null)`
- starts with `09` (Syrian local) → normalize to `+963<rest>`; return `(error: null, normalized: '+963<rest>')`
- starts with `+963` → accept as-is; return `(error: null, normalized: trim(value))`
- starts with `+` (other E.164 country code) → accept as-is; return `(error: null, normalized: trim(value))`
- contains non-digit non-`+` non-` ` non-`-` characters → `(error: l10n.validatorPhoneInvalid, normalized: null)`
- otherwise → fall through to `validatorPhoneInvalid`

The same validator reuses Phase 5's `PhoneNumber` value object normalization logic; Phase 10 wraps it as a validator without duplicating the E.164 logic.

## Verification (manual goldens)

| Validator | Input | Expected output |
|---|---|---|
| AreaSize | `null` | `l10n.validatorAreaSizePositive` |
| AreaSize | `-5` | `l10n.validatorAreaSizePositive` |
| AreaSize | `0` | `l10n.validatorAreaSizePositive` |
| AreaSize | `120` | `null` (pass) |
| AreaSize | `7500` | `null` (pass, with soft warning rendered by form widget) |
| AreaSize | `1000000` | `l10n.validatorAreaSizeTooLarge` |
| Price | `Decimal.fromInt(0)` | `l10n.validatorPricePositive` |
| Price | `Decimal.parse('-50')` | `l10n.validatorPricePositive` |
| Price | `Decimal.parse('50000')` with USD | `null` (pass) |
| Price | `Decimal.parse('50000.123')` with USD (>2 decimals) | round-and-accept OR pass depending on impl |
| Price | `Decimal.parse('99999999999999.99')` (15 integer digits) | `l10n.validatorPriceTooPrecise` |
| Phone | `null` | `(error: invalid, normalized: null)` |
| Phone | `''` | `(error: invalid, normalized: null)` |
| Phone | `'0991234567'` | `(error: null, normalized: '+963991234567')` |
| Phone | `'+963991234567'` | `(error: null, normalized: '+963991234567')` |
| Phone | `'123'` | `(error: too_short, normalized: null)` |
| Phone | `'+1234567890'` (non-Syrian E.164) | `(error: null, normalized: '+1234567890')` |
| Phone | `'abc'` | `(error: invalid, normalized: null)` |

These goldens are exercised manually during `/speckit-implement` per the no-new-tests rule.

## Forbidden

- Adding a Supabase dependency to any validator.
- Adding a network call to any validator.
- Duplicating Phase 5's `PhoneNumber` value object normalization (the validator wraps; it does not reimplement).
- Hardcoding country codes other than Syria (the validator accepts any E.164 country, normalizes only the Syrian-local case).
