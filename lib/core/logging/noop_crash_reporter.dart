// lib/core/logging/noop_crash_reporter.dart
//
// Phase 24 (CR) — No-op [CrashReporter] bound when the Sentry DSN is empty
// (R-217, FR-007).  Mirrors [NoopPushMessagingService] (the Phase 22
// degraded-mode adapter): every method is an inert no-op, so the app builds
// and runs identically whether or not a crash dashboard is configured.
//
// This is the binding used in debug builds and in any release/profile build
// launched without a `--dart-define`d `SENTRY_DSN` — no init, no network, no
// payload ever leaves the device.

import 'crash_reporter.dart';

/// No-op implementation of [CrashReporter].
///
/// Constructed directly in `main.dart` when the DSN is empty (mirrors the
/// `NoopPushMessagingService` binding style).
class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> init({required String dsn, required String environment}) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    Map<String, Object?> context = const {},
  }) async {}

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  Future<void> close() async {}
}
