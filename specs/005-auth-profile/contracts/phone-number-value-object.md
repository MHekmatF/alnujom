# Contract: `PhoneNumber` Value Object

**Owner**: Phase 5 (`lib/shared/domain/value_objects/phone_number.dart`).
**Consumers**: Phase 5's auth feature (registration / login / reset-password); Phase 5's profile feature (display the read-only phone; validate `secondary_phone` inside `private_contact_methods`); Phase 16+ inquiries (will reuse the value object for the inquirer's phone); Phase 19+ agencies (will reuse for agency contact phones).
**Stability**: Stable across the v1 lifecycle. The hand-rolled validator may grow more lenient (e.g., add another country's specific rules) but the canonical E.164 string output and the `parse` / `tryParse` factory shape do not change.

---

## Purpose

A single, provider-agnostic representation of a phone number. Normalizes user input to E.164. Rejects malformed input at the boundary. Used as the canonical phone shape across every feature that touches phones — domain code never sees a raw `String` phone.

## Type

```dart
class PhoneNumber extends Equatable {
  /// The canonical E.164 string, e.g. "+963991234567".
  /// Always starts with '+', followed by 7..15 digits total (8..16 chars including '+').
  final String e164;

  const PhoneNumber._(this.e164);

  /// Throws PhoneNumberFormatException on invalid input.
  factory PhoneNumber.parse(String raw, {String defaultCountryCode = '+963'});

  /// Returns null on invalid input (no exception).
  static PhoneNumber? tryParse(String raw, {String defaultCountryCode = '+963'});

  @override
  List<Object?> get props => [e164];

  @override
  String toString() => e164;
}

class PhoneNumberFormatException implements Exception {
  /// Localization key for the user-facing error message. The presentation layer
  /// resolves this through Phase 3's AppLocalizations (e.g., "phone_invalid").
  final String localizationKey;

  PhoneNumberFormatException(this.localizationKey);
}
```

## Normalization rules

Applied in order. The first rule that matches determines the canonical form.

1. **Strip non-significant characters**: remove ASCII whitespace, dashes, parentheses, dots. Keep `+` and digits 0-9.
2. **Empty after strip** → throw `PhoneNumberFormatException('phone_required')`.
3. **Begins with `+`** (explicit international prefix):
   - Remaining string MUST be all digits.
   - Total length (`+` + digits) MUST be 8..16 chars (E.164 allows 1..15 digits after `+`; we set the lower bound at 7 to reject obvious garbage).
   - If the prefix is `+963` (Syria): the remaining 9 digits MUST start with `9` (Syrian mobile prefix). Other Syrian patterns (landlines) are accepted only if the overall length and digit-only constraint hold.
   - If the prefix is anything else: accepted structurally without country-specific validation.
   - Canonical form: the input as-is (after stripping).
4. **Begins with `0`** (Syrian national leading-zero format):
   - Strip the leading `0`.
   - Result MUST be all digits, 9 digits long, starting with `9`.
   - Canonical form: `+963` + the 9 digits.
5. **Digit-only without `+` and without leading `0`**:
   - If exactly 9 digits starting with `9` → treat as Syrian mobile, canonical form `+963` + the 9 digits.
   - Otherwise → throw `PhoneNumberFormatException('phone_invalid')`.
6. **Anything else** → throw `PhoneNumberFormatException('phone_invalid')`.

The `defaultCountryCode` parameter exists for future flexibility but is currently unused — the rules above are Syria-specific (per `IMPLEMENTATION_PLAN.md` §6.6 + project memory). When Phase 19 (agencies) adds non-Syrian country support, that phase's spec extends this contract; the domain calls don't change.

## Examples

| Input | Output `e164` | Notes |
|---|---|---|
| `"+963991234567"` | `"+963991234567"` | Pass-through. |
| `"+963 99 123 4567"` | `"+963991234567"` | Spaces stripped. |
| `"+963-99-123-4567"` | `"+963991234567"` | Dashes stripped. |
| `"0991234567"` | `"+963991234567"` | Leading-zero national form expanded. |
| `"991234567"` | `"+963991234567"` | Bare 9-digit Syrian mobile. |
| `"+1234567890"` | `"+1234567890"` | Non-Syrian; structural validation only. |
| `""` | throws `phone_required` | |
| `"+963 abc"` | throws `phone_invalid` | Letters not allowed. |
| `"+1"` | throws `phone_invalid` | Too short. |
| `"123"` | throws `phone_invalid` | No prefix, not Syrian-shaped. |
| `"099"` | throws `phone_invalid` | Leading-0 form too short. |

## Invariants

- **Equality** is by canonical string. `PhoneNumber.parse("+963 99 123 4567") == PhoneNumber.parse("0991234567")` evaluates to `true`.
- **`toString()` returns the canonical form.** Every code path that displays a phone uses `phoneNumber.e164` (or `toString()`); raw user input is never displayed.
- **No third-party dependencies**: the file imports only `package:equatable/equatable.dart`. No `libphonenumber_plugin`, no `phone_number` package (R-03 rationale).
- **Localization-free**: the value object knows only the localization KEY for the failure (`phone_required`, `phone_invalid`); resolving the key to a user-facing string happens in the presentation layer.

## Use sites

| Site | Usage |
|---|---|
| `RegisterPage` | Constructs from form input via `tryParse`; on null, displays the localized error and prevents submission. |
| `LoginPage` | Same. |
| `ResetPasswordPage` | Same. |
| `ProfilePage` | Reads `Profile.phone` (read-only display); never reconstructs. |
| `PrivateContactMethods.fromJson` | Parses `secondary_phone` value via `PhoneNumber.parse`; throws if invalid (domain-level rejection). |
| `request_password_reset` Edge Function | Re-implements the normalization in TypeScript — the TS port lives inline in `index.ts`. The two implementations agree on the canonical form. |

## Verification

`quickstart.md` Step "Phone-number normalization sanity" walks the seven canonical examples in the Examples table and confirms each produces the expected `e164` value.
