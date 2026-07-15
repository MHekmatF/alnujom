import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../errors/result.dart';
import '../logging/app_logger.dart';
import '../storage/preferences_store.dart';

@injectable
final class LocaleCubit extends Cubit<Locale> {
  LocaleCubit(
    this._preferencesStore,
    this._logger,
    @factoryParam Locale? initialLocale,
  ) : super(initialLocale ?? defaultLocale);

  static const defaultLocale = Locale('ar');
  static const englishLocale = Locale('en');
  static const _tag = 'LocaleCubit';

  final PreferencesStore _preferencesStore;
  final AppLogger _logger;

  Future<void> toggle() async {
    final nextLocale = state.languageCode == 'ar'
        ? englishLocale
        : defaultLocale;
    await setLocale(nextLocale);
  }

  /// Selects [locale] explicitly (used by the Settings language picker). No-ops
  /// when it already matches the current locale; otherwise emits then persists.
  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == state.languageCode) return;

    emit(locale);

    final result = await _preferencesStore.writeLocale(locale);
    if (result case FailureResult(:final failure)) {
      _logger.warning(
        'Failed to persist locale preference.',
        error: failure.cause,
        stackTrace: failure.stackTrace,
        tag: _tag,
      );
    }
  }
}
