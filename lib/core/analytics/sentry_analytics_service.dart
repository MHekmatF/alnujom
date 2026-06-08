// lib/core/analytics/sentry_analytics_service.dart
//
// Sentry-backed [AnalyticsService] — product telemetry layered on the existing
// Phase 24 (CR) Sentry seam. Mirrors [SentryCrashReporter]'s binding style:
// registered as the default DI binding for [AnalyticsService] via
// `@LazySingleton(as: AnalyticsService)`, so `getIt<AnalyticsService>()`
// resolves it everywhere.
//
// Unlike [CrashReporter] (whose runtime instance is constructed + initialized
// directly by `main.dart`), analytics is resolved purely through DI. Sentry's
// own initialization is performed once by `main.dart` (only in release/profile
// with a non-empty DSN); this service therefore gates EVERY method on the
// global `Sentry.isEnabled` flag. When Sentry was not initialized — debug
// builds, or release/profile launched without a `SENTRY_DSN` — every method is
// an inert no-op (equivalent to [NoopAnalyticsService]), so no payload ever
// leaves the device.
//
// Events are recorded as Sentry breadcrumbs (cheap navigation/event markers);
// the cold-start trace is recorded as a Sentry message tagged with the elapsed
// milliseconds. The hard `beforeSend` scrub installed by [SentryCrashReporter]
// still runs on every outgoing payload as a backstop (FR-006), so even a
// caller that accidentally passes PII props is scrubbed before transmission.
//
// This file is one of the few places `package:sentry_flutter` is imported
// outside `main.dart`; no `domain/` file imports it (Principle IX / SC-008).

import 'package:injectable/injectable.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'analytics_service.dart';

/// Sentry-backed [AnalyticsService].
@LazySingleton(as: AnalyticsService)
class SentryAnalyticsService implements AnalyticsService {
  SentryAnalyticsService();

  /// Breadcrumb category for product events / screen views.
  static const _eventCategory = 'analytics';
  static const _coldStartEvent = 'cold_start';

  @override
  void logEvent(String name, {Map<String, Object?>? props}) {
    if (!Sentry.isEnabled) return;
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: name,
        category: _eventCategory,
        // Breadcrumb data is recursively scrubbed by the shared `beforeSend`
        // backstop; callers must still pass NON-PII props (ids/counts/labels).
        data: props == null || props.isEmpty
            ? null
            : <String, dynamic>{...props},
      ),
    );
  }

  @override
  void logScreen(String name) {
    if (!Sentry.isEnabled) return;
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: name,
        category: 'navigation',
        type: 'navigation',
      ),
    );
  }

  @override
  void logColdStart(Duration d) {
    if (!Sentry.isEnabled) return;
    final ms = d.inMilliseconds;
    // Drop a breadcrumb (lightweight) AND a message (queryable on the
    // dashboard) carrying the elapsed milliseconds as the cold-start trace.
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: _coldStartEvent,
        category: _eventCategory,
        data: <String, dynamic>{'duration_ms': ms},
      ),
    );
    Sentry.captureMessage(
      'cold_start: ${ms}ms',
      level: SentryLevel.info,
      withScope: (scope) async {
        await scope.setTag('cold_start_ms', '$ms');
      },
    );
  }
}
