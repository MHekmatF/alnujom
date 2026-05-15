import 'package:equatable/equatable.dart';

/// E.164-normalized phone number value object (Phase 5 FR-014, R-03).
///
/// The Dart and TS (Edge Function) implementations agree on canonical form:
/// see `supabase/functions/request_password_reset/index.ts` `normalizeToE164`.
///
/// Normalization rules (Syria-focused):
///   1. Strip whitespace, dashes, parens, dots.
///   2. `+CC...` → keep as-is (8..16 chars, digits-only after +).
///   3. `0XXXXXXXXX` (Syrian leading-zero, 10 chars) → strip 0, prepend +963.
///      The remaining 9 digits must start with 9.
///   4. `9XXXXXXXX` (bare 9-digit Syrian mobile) → prepend +963.
///   5. Anything else → throw [PhoneNumberFormatException].
class PhoneNumber extends Equatable {
  const PhoneNumber._(this.e164);

  /// Canonical E.164 form, e.g. "+963991234567".
  final String e164;

  /// Throws [PhoneNumberFormatException] on invalid input.
  factory PhoneNumber.parse(String raw, {String defaultCountryCode = '+963'}) {
    final result = _normalize(raw);
    if (result == null) {
      // Distinguish "empty" vs. "invalid" for better UX.
      final stripped = raw.replaceAll(RegExp(r'[\s\-().]'), '');
      throw PhoneNumberFormatException(
        stripped.isEmpty ? 'phone_required' : 'phone_invalid',
      );
    }
    return PhoneNumber._(result);
  }

  /// Returns null on invalid input (no exception).
  static PhoneNumber? tryParse(
    String raw, {
    String defaultCountryCode = '+963',
  }) {
    final result = _normalize(raw);
    return result == null ? null : PhoneNumber._(result);
  }

  static String? _normalize(String raw) {
    final stripped = raw.replaceAll(RegExp(r'[\s\-().]'), '');
    if (stripped.isEmpty) return null;
    // (1) Explicit international prefix.
    if (stripped.startsWith('+')) {
      if (!RegExp(r'^\+\d+$').hasMatch(stripped)) return null;
      if (stripped.length < 8 || stripped.length > 16) return null;
      return stripped;
    }
    // (2) Syrian leading-zero national format.
    if (stripped.startsWith('0')) {
      final rest = stripped.substring(1);
      if (!RegExp(r'^\d{9}$').hasMatch(rest)) return null;
      if (!rest.startsWith('9')) return null;
      return '+963$rest';
    }
    // (3) Bare 9-digit Syrian mobile.
    if (RegExp(r'^9\d{8}$').hasMatch(stripped)) {
      return '+963$stripped';
    }
    return null;
  }

  @override
  List<Object?> get props => [e164];

  @override
  String toString() => e164;
}

/// Carries a localization key (resolved by the presentation layer).
class PhoneNumberFormatException implements Exception {
  PhoneNumberFormatException(this.localizationKey);

  final String localizationKey;

  @override
  String toString() => 'PhoneNumberFormatException($localizationKey)';
}
