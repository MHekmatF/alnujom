import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../errors/result.dart';
import '../logging/app_logger.dart';
import '../storage/preferences_store.dart';
import 'app_theme_mode.dart';

export 'app_theme_mode.dart';

@injectable
final class ThemeCubit extends Cubit<AppThemeMode> {
  ThemeCubit(this._store, this._log) : super(AppThemeMode.auto);

  @visibleForTesting
  ThemeCubit.test({required PreferencesStore store, required AppLogger log})
    : _store = store,
      _log = log,
      super(AppThemeMode.auto);

  static const _tag = 'ThemeCubit';

  final PreferencesStore _store;
  final AppLogger _log;

  Future<void> initialize() async {
    final result = await _store.readThemeMode();
    if (isClosed) return;
    final mode = switch (result) {
      Success(:final value) => value ?? AppThemeMode.auto,
      FailureResult() => _warnAndReturnAuto(),
    };
    emit(mode);
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (mode == state) return;
    final result = await _store.writeThemeMode(mode);
    if (result case FailureResult(:final failure)) {
      _log.warning(
        'Failed to persist theme preference.',
        error: failure.cause,
        stackTrace: failure.stackTrace,
        tag: _tag,
      );
    }
    emit(mode);
  }

  AppThemeMode _warnAndReturnAuto() {
    _log.warning(
      'Failed to read theme preference; defaulting to auto.',
      tag: _tag,
    );
    return AppThemeMode.auto;
  }
}
