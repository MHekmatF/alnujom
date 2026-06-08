// lib/core/analytics/analytics_service.dart
//
// Product analytics / telemetry seam — built on the existing Sentry reporting
// infrastructure (Phase 24 CR). Mirrors the [CrashReporter] seam style:
// a provider-agnostic interface in `core/` (never `domain/`) so that no domain
// file imports an analytics/crash SDK (Principle IX / SC-008).
//
// Concrete bindings:
//   - SentryAnalyticsService — forwards events as Sentry breadcrumbs and the
//     cold-start trace as a Sentry message/measurement; active only when the
//     Sentry SDK is initialized (release/profile + non-empty DSN).
//   - NoopAnalyticsService   — all no-ops; the effective binding whenever
//     Sentry is absent (debug builds, or release/profile launched without a
//     `--dart-define`d `SENTRY_DSN`).
//
// Every method is fail-soft: an implementation MUST NOT throw. Callers fire
// telemetry best-effort and never await it on a hot path.
abstract interface class AnalyticsService {
  /// Logs a product event with optional NON-PII properties.
  ///
  /// [name] is a stable snake_case identifier (e.g. `listing_viewed`).
  /// [props] is optional NON-PII metadata (ids, counts, enum labels). Values
  /// are additionally scrubbed before transmission by the underlying reporter.
  void logEvent(String name, {Map<String, Object?>? props});

  /// Logs a screen view (a navigation marker), [name] being a stable
  /// snake_case screen identifier (e.g. `home`).
  void logScreen(String name);

  /// Records the cold-start duration (process start → first frame) as a
  /// telemetry measurement.
  void logColdStart(Duration d);
}
