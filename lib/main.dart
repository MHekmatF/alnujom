import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/env_config.dart';
import 'core/di/injection.dart';
import 'core/errors/result.dart';
import 'core/localization/locale_cubit.dart';
import 'core/logging/app_logger.dart';
import 'core/network/supabase_client_wrapper.dart';
import 'core/storage/preferences_store.dart';

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

  var initialThemeMode = ThemeMode.system;
  final themeModeResult = await preferencesStore.readThemeMode();
  switch (themeModeResult) {
    case Success(:final value):
      initialThemeMode = value ?? ThemeMode.system;
    case FailureResult(:final failure):
      logger.warning(
        'Failed to read theme preference; using system theme.',
        error: failure.cause,
        stackTrace: failure.stackTrace,
        tag: 'Bootstrap',
      );
  }

  var initialLocale = LocaleCubit.defaultLocale;
  final localeResult = await preferencesStore.readLocale();
  switch (localeResult) {
    case Success(:final value):
      initialLocale = value ?? LocaleCubit.defaultLocale;
    case FailureResult(:final failure):
      logger.warning(
        'Failed to read locale preference; using Arabic locale.',
        error: failure.cause,
        stackTrace: failure.stackTrace,
        tag: 'Bootstrap',
      );
  }

  runApp(App(initialThemeMode: initialThemeMode, initialLocale: initialLocale));
}
