import 'package:alnujom/core/errors/failure.dart';
import 'package:alnujom/core/errors/result.dart';
import 'package:alnujom/core/localization/locale_cubit.dart';
import 'package:alnujom/core/logging/app_logger.dart';
import 'package:alnujom/core/storage/preferences_store.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocaleCubit', () {
    late _FakePreferencesStore store;
    late _RecordingLogger logger;

    test('initial state is Arabic when persisted value is null', () {
      final cubit = _buildCubit(initialLocale: null);

      expect(cubit.state, const Locale('ar'));
    });

    test('initial state is English when persisted value is English', () {
      final cubit = _buildCubit(initialLocale: const Locale('en'));

      expect(cubit.state, const Locale('en'));
    });

    blocTest<LocaleCubit, Locale>(
      'toggle from Arabic chooses English and writes through',
      build: () {
        store = _FakePreferencesStore();
        return _buildCubit(
          initialLocale: const Locale('ar'),
          preferencesStore: store,
        );
      },
      act: (cubit) => cubit.toggle(),
      expect: () => [const Locale('en')],
      verify: (_) => expect(store.writtenLocales, [const Locale('en')]),
    );

    blocTest<LocaleCubit, Locale>(
      'toggle from English chooses Arabic and writes through',
      build: () {
        store = _FakePreferencesStore();
        return _buildCubit(
          initialLocale: const Locale('en'),
          preferencesStore: store,
        );
      },
      act: (cubit) => cubit.toggle(),
      expect: () => [const Locale('ar')],
      verify: (_) => expect(store.writtenLocales, [const Locale('ar')]),
    );

    blocTest<LocaleCubit, Locale>(
      'write failure logs a warning without reverting in-memory state',
      build: () {
        logger = _RecordingLogger();
        return _buildCubit(
          initialLocale: const Locale('ar'),
          writeLocaleFailure: true,
          logger: logger,
        );
      },
      act: (cubit) => cubit.toggle(),
      expect: () => [const Locale('en')],
      verify: (cubit) {
        expect(logger.warningMessages.single, contains('persist locale'));
        expect(cubit.state, const Locale('en'));
      },
    );
  });
}

LocaleCubit _buildCubit({
  Locale? initialLocale,
  bool writeLocaleFailure = false,
  _FakePreferencesStore? preferencesStore,
  _RecordingLogger? logger,
}) {
  final resolvedStore =
      preferencesStore ??
      _FakePreferencesStore(writeLocaleFailure: writeLocaleFailure);
  final resolvedLogger = logger ?? _RecordingLogger();

  return LocaleCubit(
    resolvedStore,
    resolvedLogger,
    initialLocale ?? LocaleCubit.defaultLocale,
  );
}

final class _FakePreferencesStore implements PreferencesStore {
  _FakePreferencesStore({this.writeLocaleFailure = false});

  final bool writeLocaleFailure;
  final writtenLocales = <Locale>[];

  @override
  Future<Result<ThemeMode?>> readThemeMode() async => const Success(null);

  @override
  Future<Result<void>> writeThemeMode(ThemeMode mode) async =>
      const Success(null);

  @override
  Future<Result<Locale?>> readLocale() async => const Success(null);

  @override
  Future<Result<void>> writeLocale(Locale locale) async {
    writtenLocales.add(locale);
    if (writeLocaleFailure) {
      return const FailureResult(CacheFailure('write failed'));
    }
    return const Success(null);
  }
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
