// lib/core/analytics/noop_analytics_service.dart
//
// No-op [AnalyticsService] — the inert binding when the Sentry SDK is absent
// (mirrors [NoopCrashReporter] from Phase 24 CR). Every method is a no-op so
// the app builds and runs identically whether or not telemetry is configured;
// no payload ever leaves the device.
//
// This is the binding used in debug builds and in any release/profile build
// launched without a `--dart-define`d `SENTRY_DSN`.

import 'analytics_service.dart';

/// No-op implementation of [AnalyticsService].
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  void logEvent(String name, {Map<String, Object?>? props}) {}

  @override
  void logScreen(String name) {}

  @override
  void logColdStart(Duration d) {}
}
