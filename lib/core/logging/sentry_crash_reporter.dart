// lib/core/logging/sentry_crash_reporter.dart
//
// Phase 24 (CR) — the Sentry-backed [CrashReporter] (R-206, R-208, R-217).
//
// Wraps `sentry_flutter` and installs a HARD `beforeSend` scrub that runs on
// EVERY outgoing event (data-model §2 / FR-006).  The scrub is a security
// invariant: the synthetic-email <-> phone mapping, Supabase Vault material,
// decrypted PII (legal_name / national_id / private_contact_methods /
// inquirer_phone), and any auth token / JWT / bearer MUST NEVER reach the
// payload — not in `user`, `request` headers/cookies/body, `extra`, `tags`,
// `contexts`, breadcrumbs, the message, or the exception value text.
//
// This file is the ONLY place `package:sentry_flutter` is imported outside
// `main.dart`.  No `domain/` file imports it (Principle IX / SC-008).
//
// Enablement is decided by the caller (`main.dart`): bound only in
// release/profile with a non-empty DSN; otherwise the NoopCrashReporter is
// used.  Init is guarded + non-blocking so a throw/timeout never blocks
// `runApp` (FR-007).

import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'crash_reporter.dart';
import 'log_redaction.dart';

/// Sentry-backed [CrashReporter].
///
/// Registered as the default DI binding for [CrashReporter] (SC-008 — a
/// `core/` binding exists), but `main.dart` constructs the instance it wires
/// to the global handlers directly and only after a non-empty DSN is present
/// (mirrors the push-service binding style: the runtime instance is chosen by
/// the bootstrap, not resolved blindly from the graph).
@LazySingleton(as: CrashReporter)
class SentryCrashReporter implements CrashReporter {
  SentryCrashReporter();

  bool _initialized = false;

  @override
  Future<void> init({required String dsn, required String environment}) async {
    if (dsn.isEmpty) {
      // Defensive: the caller should bind NoopCrashReporter when the DSN is
      // empty; never initialize Sentry without a DSN.
      return;
    }
    await SentryFlutter.init((options) {
      options
        ..dsn = dsn
        ..environment = environment
        // Never let the SDK auto-attach IP address / request headers / user
        // identity. We attach only a non-PII user id ourselves (if any).
        ..sendDefaultPii = false
        // Keep transmission cheap on the direct-APK audience; errors only.
        ..tracesSampleRate = 0.0
        // The HARD security scrub — runs on every event before transmission.
        ..beforeSend = _scrub;
    });
    _initialized = true;
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    Map<String, Object?> context = const {},
  }) async {
    if (!_initialized) return;
    await Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) async {
        // Only NON-PII context is attached here; `beforeSend` still scrubs it
        // as a backstop. Callers must pass route/screen/version-class values
        // only (data-model §2 "Non-PII context that MAY ship").
        for (final entry in context.entries) {
          if (entry.value != null) {
            await scope.setContexts(entry.key, entry.value);
          }
        }
      },
    );
  }

  @override
  void addBreadcrumb(String message, {String? category}) {
    if (!_initialized) return;
    // Redact the message at the source; `beforeSend` scrubs again as backstop.
    Sentry.addBreadcrumb(
      Breadcrumb(message: _redactString(message), category: category),
    );
  }

  @override
  Future<void> close() async {
    if (!_initialized) return;
    await Sentry.close();
    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  // beforeSend scrub (data-model §2). Pure + total: it never throws and never
  // returns an un-scrubbed event. On any unexpected shape it strips broadly.
  // ---------------------------------------------------------------------------

  static FutureOr<SentryEvent?> _scrub(SentryEvent event, Hint hint) {
    try {
      return event.copyWith(
        // Replace the request with a minimal url/method-only copy: drop
        // headers (bearer/JWT/cookies), query string, body, and env.
        request: _scrubRequest(event.request),
        // Keep at most a non-PII stable id; never name/phone/email/ip/geo.
        user: _scrubUser(event.user),
        // Recursively redact arbitrary attached maps. `extra` is deprecated in
        // the SDK but still serialized into the payload, so we MUST scrub it
        // (dropping the scrub would be a security regression — FR-006).
        // ignore: deprecated_member_use
        extra: _redactMap(event.extra),
        tags: _redactStringMap(event.tags),
        contexts: _scrubContexts(event.contexts),
        breadcrumbs: _scrubBreadcrumbs(event.breadcrumbs),
        message: _scrubMessage(event.message),
        exceptions: _scrubExceptions(event.exceptions),
        // Threads carry their own stack traces; clear frame-local `vars` (the
        // only PII surface) while keeping file/function/line for debugging.
        threads: _scrubThreads(event.threads),
      );
    } catch (_) {
      // If scrubbing fails for any reason, fail CLOSED on PII: drop the event
      // rather than risk transmitting un-scrubbed data.
      return null;
    }
  }

  static SentryRequest? _scrubRequest(SentryRequest? request) {
    if (request == null) return null;
    // Rebuild with only url + method; everything else (headers, cookies,
    // queryString, data, env) is dropped. The url itself is redacted because a
    // synthetic `<phone>@alnujom.local`, a token, or a query string can be
    // embedded in the path/query.
    return SentryRequest(
      url: request.url == null ? null : _redactString(request.url!),
      method: request.method,
    );
  }

  static SentryUser? _scrubUser(SentryUser? user) {
    if (user == null) return null;
    // ALWAYS rebuild with an id-only user. Returning `null` here would be a PII
    // leak: `SentryEvent.copyWith` coalesces `user ?? this.user`, so a null
    // return KEEPS the original user untouched (email / phone / ipAddress /
    // geo / data). Keep only the non-PII stable id (data-model §2); when it is
    // absent (anonymous), fall back to a constant so the original is still
    // overwritten and the SentryUser assert (>=1 non-null field) holds in every
    // build mode. The id is NOT run through `_redactString` — that would mangle
    // a legitimate UUID id (its digit runs match the phone pattern).
    return SentryUser(id: user.id ?? _redacted);
  }

  static SentryMessage? _scrubMessage(SentryMessage? message) {
    if (message == null) return null;
    return SentryMessage(
      _redactString(message.formatted),
      template: message.template == null
          ? null
          : _redactString(message.template!),
      // Drop interpolation params entirely (may carry raw PII).
      params: null,
    );
  }

  static List<SentryException>? _scrubExceptions(
    List<SentryException>? exceptions,
  ) {
    if (exceptions == null) return null;
    return exceptions
        .map(
          (e) => e.copyWith(
            value: e.value == null ? null : _redactString(e.value!),
            // Strip frame-local variable values from the exception's stack
            // trace; keep the frames themselves (file/function/line).
            stackTrace: _scrubStackTrace(e.stackTrace),
          ),
        )
        .toList(growable: false);
  }

  static List<SentryThread>? _scrubThreads(List<SentryThread>? threads) {
    if (threads == null) return null;
    return threads
        .map((t) => t.copyWith(stacktrace: _scrubStackTrace(t.stacktrace)))
        .toList(growable: false);
  }

  /// Clears frame-local variable maps (`vars`) from every frame while keeping
  /// the frame's code location (file / function / line / col), which carries no
  /// PII and is what makes a crash actionable. Returns `null` for a `null`
  /// input so the SDK's `?? this.X` coalescing is a no-op (nothing to scrub).
  static SentryStackTrace? _scrubStackTrace(SentryStackTrace? stackTrace) {
    if (stackTrace == null) return null;
    return stackTrace.copyWith(
      frames: stackTrace.frames
          .map((f) => f.copyWith(vars: const <String, String>{}))
          .toList(growable: false),
    );
  }

  static List<Breadcrumb>? _scrubBreadcrumbs(List<Breadcrumb>? breadcrumbs) {
    if (breadcrumbs == null) return null;
    return breadcrumbs
        .map(
          (b) => b.copyWith(
            message: b.message == null ? null : _redactString(b.message!),
            data: _redactMap(b.data),
          ),
        )
        .toList(growable: false);
  }

  static Contexts _scrubContexts(Contexts contexts) {
    final scrubbed = contexts.clone();
    for (final key in scrubbed.keys.toList()) {
      final value = scrubbed[key];
      scrubbed[key] = _redactValue(value);
    }
    return scrubbed;
  }

  // --- value-level redaction -------------------------------------------------

  /// Keys whose VALUES are always stripped (case-insensitive substring match).
  static const _sensitiveKeyFragments = <String>[
    // tokens / auth
    'token', 'authorization', 'bearer', 'apikey', 'api_key', 'secret',
    'password', 'passwd', 'jwt', 'access_token', 'refresh_token', 'cookie',
    'session',
    // Vault material
    'vault', 'service_account', 'fcm_service_account', 'push_dispatch_token',
    'private_key', 'privatekey',
    // decrypted PII (ADR-0001 Vault fields)
    'legal_name', 'national_id', 'private_contact', 'inquirer_phone',
    'phone', 'email', 'name',
  ];

  static const _redacted = '[redacted]';

  static Map<String, dynamic>? _redactMap(Map<String, dynamic>? input) {
    if (input == null) return null;
    final out = <String, dynamic>{};
    input.forEach((key, value) {
      if (_isSensitiveKey(key)) {
        out[key] = _redacted;
      } else {
        out[key] = _redactValue(value);
      }
    });
    return out;
  }

  static Map<String, String>? _redactStringMap(Map<String, String>? input) {
    if (input == null) return null;
    final out = <String, String>{};
    input.forEach((key, value) {
      out[key] = _isSensitiveKey(key) ? _redacted : _redactString(value);
    });
    return out;
  }

  static dynamic _redactValue(dynamic value) {
    if (value is String) return _redactString(value);
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        final key = k.toString();
        out[key] = _isSensitiveKey(key) ? _redacted : _redactValue(v);
      });
      return out;
    }
    if (value is List) {
      return value.map(_redactValue).toList(growable: false);
    }
    return value;
  }

  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    for (final fragment in _sensitiveKeyFragments) {
      if (lower.contains(fragment)) return true;
    }
    return false;
  }

  /// Redacts sensitive substrings embedded in free text. Delegates to the
  /// shared [LogRedaction] scrubber so the console logger and crash reporter
  /// stay in lock-step (single source of truth for the token/PII regexes).
  static String _redactString(String input) => LogRedaction.redactText(input);
}
