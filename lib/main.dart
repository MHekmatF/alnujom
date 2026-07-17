import 'dart:async';

import 'app.dart';
import 'core/analytics/analytics_service.dart';
import 'core/config/env_config.dart';
import 'core/di/injection.dart';
import 'core/errors/result.dart';
import 'core/localization/locale_cubit.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/crash_reporter.dart';
import 'core/logging/noop_crash_reporter.dart';
import 'core/logging/sentry_crash_reporter.dart';
import 'core/messaging/push_messaging_service.dart';
import 'core/network/supabase_client_wrapper.dart';
import 'core/network/types/auth_state.dart' as app_auth;
import 'core/notifications/local_reminder_scheduler.dart';
import 'core/storage/preferences_store.dart';
import 'features/crm/domain/repositories/crm_repository.dart';
import 'features/notifications/data/datasources/fcm_push_messaging_service.dart';
import 'features/notifications/data/datasources/noop_push_messaging_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Phase 24 (CR) — crash & error reporting (R-206, R-208, R-217).
//
// The Sentry DSN is supplied at compile time via a `--dart-define`d
// `SENTRY_DSN` (`--dart-define-from-file=.env.json`). An EMPTY DSN ⇒ the
// NoopCrashReporter is bound (no init, no network). Reporting is enabled only
// in release/profile builds; debug builds stay console-only (the seam is inert
// in debug regardless of DSN).
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

// Phase 22 — top-level background-message handler required by firebase_messaging.
//
// Must be a top-level function (not a closure or method).  The history row has
// already been written by `enqueue_notification` + the `notify_push_dispatch`
// trigger before this runs, so no database write is needed here.  The in-app
// center will show the notification on next open/resume (R-193).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // No-op: history is written server-side.  Client-side badge refresh happens
  // on foreground-resume via NotificationBadgeCubit (PN phase, T029).
}

Future<void> main() async {
  // Product analytics / telemetry — cold-start trace. Start the clock at the
  // very top of bootstrap; we stop it after the first frame is rendered (see
  // `_bootstrap`) and forward the elapsed time to the AnalyticsService.
  final coldStartWatch = Stopwatch()..start();

  // Phase 24 (CR) — choose + guard-init the crash reporter, then run the
  // existing bootstrap inside `runZonedGuarded` so async errors are captured.
  //
  // Enablement (R-217): release/profile only AND a non-empty DSN. Otherwise
  // the NoopCrashReporter is bound — no init, no network, fully inert. Init is
  // wrapped in try/catch (the Phase 22 Firebase-guard pattern) so a throw or
  // timeout NEVER blocks `runApp` (FR-007); on failure we fall back to Noop.
  final bool crashEnabled =
      _sentryDsn.isNotEmpty && (kReleaseMode || kProfileMode);

  CrashReporter reporter = const NoopCrashReporter();
  if (crashEnabled) {
    final sentry = SentryCrashReporter();
    try {
      await sentry.init(
        dsn: _sentryDsn,
        environment: kReleaseMode ? 'release' : 'profile',
      );
      reporter = sentry;
    } catch (_) {
      // Sentry failed to initialize (unreachable endpoint, bad DSN, etc.).
      // The app must run normally regardless — fall back to the no-op adapter.
      reporter = const NoopCrashReporter();
    }
  }

  // Route framework + platform uncaught errors to the reporter. In debug these
  // forward to the Noop (inert) and Flutter still prints them to the console.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    unawaited(
      reporter.recordError(
        details.exception,
        details.stack,
        context: {'flutter_error': details.context?.toString()},
      ),
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    unawaited(reporter.recordError(error, stack));
    return true;
  };

  // Run the bootstrap inside a guarded zone so uncaught async errors (outside
  // the framework/platform handlers above) are also forwarded.
  unawaited(
    runZonedGuarded(() => _bootstrap(coldStartWatch), (error, stack) {
      unawaited(reporter.recordError(error, stack));
    }),
  );
}

/// The original bootstrap sequence (DI, Supabase, locale) — unchanged behavior,
/// now invoked from inside `runZonedGuarded`.
///
/// [coldStartWatch] is started at the top of `main()`; after the first frame
/// renders we stop it and forward the elapsed time + an `app_open` event to the
/// AnalyticsService (best-effort, never blocks startup).
Future<void> _bootstrap(Stopwatch coldStartWatch) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phase 22 — guarded Firebase init (R-195, SC-003).
  //
  // `google-services.json` is intentionally absent in CI and degraded-mode
  // environments (Syria-sanctions risk, FR-013/SC-003/SC-010).  When the
  // file is missing, Firebase.initializeApp() throws; we catch it, log a
  // warning, and register NoopPushMessagingService so every other feature
  // continues to work normally.
  //
  // When init succeeds we register FcmPushMessagingService via GetIt so that
  // the DI graph (populated by configureDependencies() below) can resolve
  // PushMessagingService from it.  We also request notification permission
  // and set up the background-message handler.
  PushMessagingService pushService;
  try {
    await Firebase.initializeApp();
    // UX-1 / PERF-M3 — notification permission (Android 13+) is requested LATER,
    // after the first frame renders (see the post-frame callback after runApp),
    // so the OS dialog appears over the branded splash instead of a black screen
    // during cold start, and its await no longer sits on the startup path.
    // Background-message handler must be a top-level function; the handler
    // here is intentionally minimal — the trigger + dispatch_push Edge
    // Function already wrote the history row, so the in-app center will show
    // it on next open/resume without any client-side processing needed.
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    pushService = FcmPushMessagingService(FirebaseMessaging.instance);
  } catch (e) {
    // Firebase not configured or blocked → use the no-op adapter.
    // The app continues normally; push is silently disabled (FR-013).
    pushService = const NoopPushMessagingService();
  }

  // Register the push service BEFORE configureDependencies() so that the
  // injectable-generated code does not attempt to resolve PushMessagingService
  // through a factory (which would need FirebaseMessaging in the graph).
  // The singleton registered here wins over any generated binding.
  getIt.registerSingleton<PushMessagingService>(pushService);

  await configureDependencies();

  final logger = getIt<AppLogger>();
  logger.info('Dependency injection configured.', tag: 'Bootstrap');

  final env = getIt<EnvConfig>();
  final wrapper = getIt<SupabaseClientWrapper>();
  final initResult = await wrapper.initialize(
    url: env.supabaseUrl,
    anonKey: env.supabaseAnonKey,
  );

  if (initResult case FailureResult(:final failure)) {
    logger.warning(failure.message, tag: 'SupabaseClientWrapper');
  }

  final preferencesStore = getIt<PreferencesStore>();

  // Arabic-first (Constitution V): default to Arabic on first launch regardless
  // of the device's system locale. A stored user preference still wins.
  var initialLocale = LocaleCubit.defaultLocale;
  final localeResult = await preferencesStore.readLocale();
  switch (localeResult) {
    case Success(:final value):
      if (value != null) initialLocale = value;
    case FailureResult(:final failure):
      logger.warning(
        'Failed to read locale preference; defaulting to Arabic.',
        error: failure.cause,
        stackTrace: failure.stackTrace,
        tag: 'Bootstrap',
      );
  }

  runApp(App(initialLocale: initialLocale));

  // Product analytics / telemetry — emit the cold-start trace + `app_open`
  // event after the first frame is rendered. Resolved through DI (the Sentry-
  // backed binding when telemetry is configured, else a no-op). Wrapped so a
  // throw here never affects the running app, and read AFTER `runApp` so the
  // DI graph is fully populated.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    coldStartWatch.stop();
    try {
      final analytics = getIt<AnalyticsService>();
      analytics.logColdStart(coldStartWatch.elapsed);
      analytics.logEvent('app_open');
    } catch (_) {
      // Telemetry is strictly best-effort — never disrupt the app.
    }

    // Phase 29 (F1) — once auth is ready, (re)schedule the signed-in
    // publisher's open CRM follow-up reminders as device-local notifications
    // (there is no server scheduler). Best-effort + guarded.
    try {
      _scheduleCrmRemindersOnAuth();
    } catch (_) {
      // Never disrupt the app for a reminder reschedule.
    }

    // UX-1 / PERF-M3 — deferred notification-permission prompt. Requested here
    // (post-first-frame) rather than during bootstrap so the Android 13+ system
    // dialog appears over the rendered splash/branding, not a black cold-start
    // screen. Only when Firebase initialised (FCM push active); best-effort.
    if (pushService is FcmPushMessagingService) {
      try {
        FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {
        // Permission request is best-effort — a throw must not disrupt startup.
      }
    }
  });
}

/// Listens for the signed-in auth state and (re)schedules the publisher's open
/// CRM follow-up reminders. Fully guarded — any failure is swallowed.
void _scheduleCrmRemindersOnAuth() {
  late final SupabaseClientWrapper wrapper;
  try {
    wrapper = getIt<SupabaseClientWrapper>();
  } catch (_) {
    return;
  }

  Future<void> reschedule() async {
    try {
      final repo = getIt<CrmRepository>();
      final scheduler = getIt<LocalReminderScheduler>();
      final result = await repo.loadOpenReminders();
      switch (result) {
        case Success(:final value):
          final now = DateTime.now();
          final items = value
              .where((r) => r.isOpenFuture(now))
              .map((r) => (id: r.id, title: r.title, due: r.dueAt))
              .toList();
          await scheduler.syncOpenReminders(items);
        case FailureResult():
          break;
      }
    } catch (_) {
      // Best-effort.
    }
  }

  wrapper.authStateChanges().listen((state) {
    if (state == app_auth.AuthState.signedIn) {
      unawaited(reschedule());
    }
  });
}
