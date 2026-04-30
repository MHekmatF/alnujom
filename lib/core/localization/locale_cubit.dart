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

    emit(nextLocale);

    final result = await _preferencesStore.writeLocale(nextLocale);
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
