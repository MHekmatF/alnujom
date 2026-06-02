// lib/core/logging/crash_reporter.dart
//
// Phase 24 (CR) — the crash & error-reporting seam (R-206, R-208, R-217).
//
// A provider-agnostic interface for forwarding uncaught/fatal errors to a
// crash dashboard.  Lives in `core/` (never `domain/`) so that no domain file
// imports a crash SDK (Principle IX / SC-008).  The concrete bindings are:
//   - [SentryCrashReporter] — wraps `sentry_flutter`; bound when a DSN is set.
//   - NoopCrashReporter      — all no-ops; bound when the DSN is empty.
//
// The seam mirrors the existing [AppLogger] contract style (the two may be
// composed later, but CR does NOT change AppLogger).  Every method is
// fail-soft: an implementation MUST NOT throw, and init MUST NOT block
// `runApp` (FR-007).
abstract interface class CrashReporter {
  /// Initializes the crash reporter.
  ///
  /// [dsn] is supplied via a `--dart-define`d `SENTRY_DSN`; an empty DSN means
  /// the caller should bind the no-op reporter instead of calling this.
  /// [environment] is the build flavor (e.g. `release`/`profile`).
  ///
  /// Implementations MUST be guarded so a throw/timeout never blocks the host
  /// app (the caller additionally wraps this in a try/catch — FR-007).
  Future<void> init({required String dsn, required String environment});

  /// Records a (possibly uncaught) error + stack to the dashboard.
  ///
  /// [context] is optional NON-PII metadata (route/screen, app version, etc.).
  /// The transmitted payload is scrubbed of secrets/PII by the implementation
  /// (the `beforeSend` scrub — data-model §2 / FR-006).
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    Map<String, Object?> context,
  });

  /// Adds a breadcrumb (a navigation/event marker) to the next event.
  ///
  /// Breadcrumbs MUST contain no PII/secrets; they are additionally scrubbed
  /// before transmission.
  void addBreadcrumb(String message, {String? category});

  /// Flushes and shuts the reporter down (e.g. on a controlled teardown).
  Future<void> close();
}
