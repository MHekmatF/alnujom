// lib/core/logging/log_redaction.dart
//
// Single source of truth for scrubbing sensitive substrings out of free text
// before it is logged or shipped to crash reporting. Used by both
// [ConsoleLogger] (so even DEBUG-build console output carries no tokens/PII if a
// debug APK leaks or a debug session is attached) and [SentryCrashReporter]
// (release crash events). Fail-closed / broad-on-purpose: over-redaction of a
// log line is always preferable to leaking a credential or PII.
library;

/// Text-level PII/secret scrubber shared across logging + crash reporting.
abstract final class LogRedaction {
  static const redactedPlaceholder = '[redacted]';

  // Synthetic auth email: `<phone>@alnujom.local`.
  static final _syntheticEmail = RegExp(
    r'[A-Za-z0-9._%+\-]+@alnujom\.local',
    caseSensitive: false,
  );

  // Any email-shaped token.
  static final _anyEmail = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
  );

  // JWT (three base64url segments) — covers Supabase access/refresh tokens.
  static final _jwt = RegExp(
    r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+',
  );

  // `Bearer <token>` headers/strings.
  static final _bearer = RegExp(r'[Bb]earer\s+[A-Za-z0-9._\-]+');

  // Phone-like runs (the synthetic email encodes the raw phone). 7+ digits,
  // optional leading + and separators — broad on purpose (fail-closed on PII).
  static final _phone = RegExp(r'\+?\d[\d\s\-()]{6,}\d');

  /// Redacts sensitive substrings (JWTs, bearer tokens, emails, phones)
  /// embedded in free text. Returns the input unchanged when empty.
  static String redactText(String input) {
    if (input.isEmpty) return input;
    var out = input;
    out = out.replaceAll(_jwt, redactedPlaceholder);
    out = out.replaceAll(_bearer, redactedPlaceholder);
    out = out.replaceAll(_syntheticEmail, redactedPlaceholder);
    out = out.replaceAll(_anyEmail, redactedPlaceholder);
    out = out.replaceAll(_phone, redactedPlaceholder);
    return out;
  }
}
