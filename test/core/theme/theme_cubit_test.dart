import 'package:alnujom/core/errors/failure.dart';
import 'package:alnujom/core/errors/result.dart';
import 'package:alnujom/core/logging/app_logger.dart';
import 'package:alnujom/core/storage/preferences_store.dart';
import 'package:alnujom/core/theme/theme_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeCubit', () {
    late _FakePreferencesStore store;
    late _RecordingLogger logger;

    test('initial state is system when persisted value is null', () {
      final cubit = _buildCubit(initialMode: null);

      expect(cubit.state, ThemeMode.system);
    });

    test('initial state is dark when persisted value is dark', () {
      final cubit = _buildCubit(initialMode: ThemeMode.dark);

      expect(cubit.state, ThemeMode.dark);
    });

    blocTest<ThemeCubit, ThemeMode>(
      'toggle from system chooses light when platform is dark and writes through',
      build: () {
        store = _FakePreferencesStore();
        return _buildCubit(
          initialMode: ThemeMode.system,
          platformBrightness: Brightness.dark,
          preferencesStore: store,
        );
      },
      act: (cubit) => cubit.toggle(),
      expect: () => [ThemeMode.light],
      verify: (_) => expect(store.writtenThemeModes, [ThemeMode.light]),
    );

    blocTest<ThemeCubit, ThemeMode>(
      'toggle from light chooses dark and writes through',
      build: () {
        store = _FakePreferencesStore();
        return _buildCubit(
          initialMode: ThemeMode.light,
          preferencesStore: store,
        );
      },
      act: (cubit) => cubit.toggle(),
      expect: () => [ThemeMode.dark],
      verify: (_) => expect(store.writtenThemeModes, [ThemeMode.dark]),
    );

    blocTest<ThemeCubit, ThemeMode>(
      'write failure logs a warning without reverting in-memory state',
      build: () {
        logger = _RecordingLogger();
        return _buildCubit(
          initialMode: ThemeMode.light,
          writeThemeFailure: true,
          logger: logger,
        );
      },
      act: (cubit) => cubit.toggle(),
      expect: () => [ThemeMode.dark],
      verify: (cubit) {
        expect(logger.warningMessages.single, contains('persist theme'));
        expect(cubit.state, ThemeMode.dark);
      },
    );
  });
}

ThemeCubit _buildCubit({
  ThemeMode? initialMode,
  Brightness platformBrightness = Brightness.light,
  bool writeThemeFailure = false,
  _FakePreferencesStore? preferencesStore,
  _RecordingLogger? logger,
}) {
  final resolvedStore =
      preferencesStore ??
      _FakePreferencesStore(writeThemeFailure: writeThemeFailure);
  final resolvedLogger = logger ?? _RecordingLogger();

  return ThemeCubit.test(
    preferencesStore: resolvedStore,
    logger: resolvedLogger,
    initialMode: initialMode ?? ThemeMode.system,
    platformBrightness: platformBrightness,
  );
}

final class _FakePreferencesStore implements PreferencesStore {
  _FakePreferencesStore({this.writeThemeFailure = false});

  final bool writeThemeFailure;
  final writtenThemeModes = <ThemeMode>[];

  @override
  Future<Result<ThemeMode?>> readThemeMode() async => const Success(null);

  @override
  Future<Result<void>> writeThemeMode(ThemeMode mode) async {
    writtenThemeModes.add(mode);
    if (writeThemeFailure) {
      return const FailureResult(CacheFailure('write failed'));
    }
    return const Success(null);
  }

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
