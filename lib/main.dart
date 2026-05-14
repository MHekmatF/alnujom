import 'app.dart';
import 'core/config/env_config.dart';
import 'core/di/injection.dart';
import 'core/errors/result.dart';
import 'core/localization/locale_cubit.dart';
import 'core/logging/app_logger.dart';
import 'core/network/supabase_client_wrapper.dart';
import 'core/storage/preferences_store.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    final systemLocale =
        WidgetsBinding.instance.platformDispatcher.locale;
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
