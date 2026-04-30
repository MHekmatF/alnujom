import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../errors/result.dart';
import '../logging/app_logger.dart';
import '../storage/preferences_store.dart';

@injectable
final class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(
    this._preferencesStore,
    this._logger,
    @factoryParam ThemeMode? initialMode,
  ) : _platformBrightness = _readPlatformBrightness,
      super(initialMode ?? ThemeMode.system);

  @visibleForTesting
  ThemeCubit.test({
    required PreferencesStore preferencesStore,
    required AppLogger logger,
    required ThemeMode initialMode,
    required Brightness platformBrightness,
  }) : _preferencesStore = preferencesStore,
       _logger = logger,
       _platformBrightness = (() => platformBrightness),
       super(initialMode);

  static const _tag = 'ThemeCubit';

  final PreferencesStore _preferencesStore;
  final AppLogger _logger;
  final Brightness Function() _platformBrightness;

  Future<void> toggle() async {
    final nextMode = switch (state) {
      ThemeMode.system => switch (_platformBrightness()) {
        Brightness.dark => ThemeMode.light,
        Brightness.light => ThemeMode.dark,
      },
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
    };

    emit(nextMode);

    final result = await _preferencesStore.writeThemeMode(nextMode);
    if (result case FailureResult(:final failure)) {
      _logger.warning(
        'Failed to persist theme preference.',
        error: failure.cause,
        stackTrace: failure.stackTrace,
        tag: _tag,
      );
    }
  }

  static Brightness _readPlatformBrightness() =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
}
