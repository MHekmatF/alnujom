import 'package:alnujom/core/errors/result.dart';
import 'package:alnujom/core/logging/app_logger.dart';
import 'package:alnujom/core/storage/preferences_store.dart';
import 'package:alnujom/core/theme/app_theme_mode.dart';
import 'package:alnujom/core/theme/color_palette.dart';
import 'package:alnujom/core/theme/palette_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaletteCubit', () {
    test('initialize() with no persisted value keeps ModernPalette', () async {
      final cubit = _buildCubit(designToolsEnabled: true);

      await cubit.initialize();

      expect(cubit.state, isA<ModernPalette>());
    });

    test('initialize() with trust persisted emits TrustPalette', () async {
      final cubit = _buildCubit(paletteName: 'trust', designToolsEnabled: true);

      await cubit.initialize();

      expect(cubit.state, isA<TrustPalette>());
    });

    test(
      'initialize() with corrupt value emits ModernPalette and logs',
      () async {
        final logger = _RecordingLogger();
        final cubit = _buildCubit(
          paletteName: 'corrupted',
          logger: logger,
          designToolsEnabled: true,
        );

        await cubit.initialize();

        expect(cubit.state, isA<ModernPalette>());
        expect(logger.warningMessages.single, contains('unrecognized palette'));
      },
    );

    test('cycle() from Modern emits Trust and persists trust', () async {
      final store = _FakePreferencesStore();
      final cubit = _buildCubit(store: store, designToolsEnabled: true);

      await cubit.cycle();

      expect(cubit.state, isA<TrustPalette>());
      expect(store.writtenPaletteNames, ['trust']);
    });

    test('cycle() twice returns to Modern and persists both states', () async {
      final store = _FakePreferencesStore();
      final cubit = _buildCubit(store: store, designToolsEnabled: true);

      await cubit.cycle();
      await cubit.cycle();

      expect(cubit.state, isA<ModernPalette>());
      expect(store.writtenPaletteNames, ['trust', 'modern']);
    });

    test(
      'release pin ignores persisted trust and makes cycle a no-op',
      () async {
        final store = _FakePreferencesStore(paletteName: 'trust');
        final cubit = _buildCubit(store: store, designToolsEnabled: false);

        await cubit.initialize();
        await cubit.cycle();

        expect(cubit.state, isA<ModernPalette>());
        expect(store.readPaletteCalls, 0);
        expect(store.writtenPaletteNames, isEmpty);
      },
    );
  });
}

PaletteCubit _buildCubit({
  String? paletteName,
  _FakePreferencesStore? store,
  _RecordingLogger? logger,
  required bool designToolsEnabled,
}) {
  return PaletteCubit.test(
    store: store ?? _FakePreferencesStore(paletteName: paletteName),
    log: logger ?? _RecordingLogger(),
    designToolsEnabled: designToolsEnabled,
  );
}

final class _FakePreferencesStore implements PreferencesStore {
  _FakePreferencesStore({this.paletteName});

  String? paletteName;
  int readPaletteCalls = 0;
  final writtenPaletteNames = <String>[];

  @override
  Future<Result<String?>> readPaletteName() async {
    readPaletteCalls += 1;
    return Success(paletteName);
  }

  @override
  Future<Result<void>> writePalette(ColorPalette palette) async {
    writtenPaletteNames.add(palette.name);
    paletteName = palette.name;
    return const Success(null);
  }

  @override
  Future<Result<AppThemeMode?>> readThemeMode() async => const Success(null);

  @override
  Future<Result<void>> writeThemeMode(AppThemeMode mode) async =>
      const Success(null);

  @override
  Future<Result<Locale?>> readLocale() async => const Success(null);

  @override
  Future<Result<void>> writeLocale(Locale locale) async => const Success(null);
}

final class _RecordingLogger implements AppLogger {
  final warningMessages = <String>[];

  @override
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {}

  @override
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {}

  @override
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    warningMessages.add(message);
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {}
}
