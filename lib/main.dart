import 'app.dart';
import 'core/config/env_config.dart';
import 'core/di/injection.dart';
import 'core/errors/result.dart';
import 'core/localization/locale_cubit.dart';
import 'core/logging/app_logger.dart';
import 'core/messaging/push_messaging_service.dart';
import 'core/network/supabase_client_wrapper.dart';
import 'core/storage/preferences_store.dart';
import 'features/notifications/data/datasources/fcm_push_messaging_service.dart';
import 'features/notifications/data/datasources/noop_push_messaging_service.dart';
import 'l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

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
