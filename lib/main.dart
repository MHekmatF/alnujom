import 'dart:async';
import 'dart:ui';

import 'app.dart';
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
import 'core/storage/preferences_store.dart';
import 'features/notifications/data/datasources/fcm_push_messaging_service.dart';
import 'features/notifications/data/datasources/noop_push_messaging_service.dart';
import 'l10n/app_localizations.dart';
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
    runZonedGuarded(_bootstrap, (error, stack) {
      unawaited(reporter.recordError(error, stack));
    }),
  );
}

/// The original bootstrap sequence (DI, Supabase, locale) — unchanged behavior,
/// now invoked from inside `runZonedGuarded`.
Future<void> _bootstrap() async {
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
    // Request notification permission (Android 13+ requires explicit prompt).
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
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

  // Resolution: stored preference > device system locale (if supported) > Arabic.
  // Constitution V: Arabic-first remains the final fallback when the device
  // locale isn't a supported one.
  Locale defaultFromDevice() {
    final supported = AppLocalizations.supportedLocales
        .map((l) => l.languageCode)
        .toSet();
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    if (supported.contains(systemLocale.languageCode)) {
      return Locale(systemLocale.languageCode);
    }
    return LocaleCubit.defaultLocale;
  }

  var initialLocale = defaultFromDevice();
  final localeResult = await preferencesStore.readLocale();
  switch (localeResult) {
    case Success(:final value):
      if (value != null) initialLocale = value;
    case FailureResult(:final failure):
      logger.warning(
        'Failed to read locale preference; using device locale fallback.',
        error: failure.cause,
        stackTrace: failure.stackTrace,
        tag: 'Bootstrap',
      );
  }

  runApp(App(initialLocale: initialLocale));
}
