import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../errors/result.dart';
import '../flags/app_flags.dart';
import '../logging/app_logger.dart';
import '../storage/preferences_store.dart';
import 'color_palette.dart';

@injectable
final class PaletteCubit extends Cubit<ColorPalette> {
  PaletteCubit(
    this._store,
    this._log, {
    bool designToolsEnabled = kDesignToolsEnabled,
  }) : _designToolsEnabled = designToolsEnabled,
       super(ColorPalette.defaultPalette);

  @visibleForTesting
  PaletteCubit.test({
    required PreferencesStore store,
    required AppLogger log,
    bool designToolsEnabled = kDesignToolsEnabled,
  }) : _store = store,
       _log = log,
       _designToolsEnabled = designToolsEnabled,
       super(ColorPalette.defaultPalette);

  static const _tag = 'PaletteCubit';

  final PreferencesStore _store;
  final AppLogger _log;
  final bool _designToolsEnabled;

  Future<void> initialize() async {
    if (!_designToolsEnabled) {
      emit(ColorPalette.defaultPalette);
      return;
    }

    final result = await _store.readPaletteName();
    final palette = switch (result) {
      Success(:final value) => _paletteFromStoredName(value),
      FailureResult(:final failure) => _warnAndReturnModern(
        'Failed to read palette preference; defaulting to Modern.',
        error: failure.cause,
        stackTrace: failure.stackTrace,
      ),
    };
    emit(palette);
  }

  Future<void> cycle() async {
    if (!_designToolsEnabled) return;

    final next = state is ModernPalette
        ? const TrustPalette()
        : ColorPalette.defaultPalette;
    final result = await _store.writePalette(next);
    if (result case FailureResult(:final failure)) {
      _log.warning(
        'Failed to persist palette preference.',
        error: failure.cause,
        stackTrace: failure.stackTrace,
        tag: _tag,
      );
    }
    emit(next);
  }

  ColorPalette _paletteFromStoredName(String? raw) {
    if (raw == null) return ColorPalette.defaultPalette;

    final normalized = raw.toLowerCase();
    if (normalized != 'modern' && normalized != 'trust') {
      return _warnAndReturnModern(
        'Ignoring unrecognized palette preference: $raw',
      );
    }
    return ColorPalette.fromName(normalized);
  }

  ColorPalette _warnAndReturnModern(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log.warning(message, error: error, stackTrace: stackTrace, tag: _tag);
    return ColorPalette.defaultPalette;
  }
}
