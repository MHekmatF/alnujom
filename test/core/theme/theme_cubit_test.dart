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
    test('initial state is auto', () {
      final cubit = _buildCubit();
      expect(cubit.state, AppThemeMode.auto);
    });

    blocTest<ThemeCubit, AppThemeMode>(
      'initialize() with no persisted value emits auto',
      build: () => _buildCubit(readResult: const Success(null)),
      act: (cubit) => cubit.initialize(),
      expect: () => [AppThemeMode.auto],
    );

    blocTest<ThemeCubit, AppThemeMode>(
      'initialize() with light persisted emits light',
      build: () => _buildCubit(readResult: const Success(AppThemeMode.light)),
      act: (cubit) => cubit.initialize(),
      expect: () => [AppThemeMode.light],
    );

    blocTest<ThemeCubit, AppThemeMode>(
      'initialize() with dark persisted emits dark',
      build: () => _buildCubit(readResult: const Success(AppThemeMode.dark)),
      act: (cubit) => cubit.initialize(),
      expect: () => [AppThemeMode.dark],
    );

    test(
      'initialize() with FailureResult emits auto and logs warning at cubit',
      () async {
        final logger = _RecordingLogger();
        final cubit = _buildCubit(
          readResult: const FailureResult(CacheFailure('disk error')),
          logger: logger,
        );
        await cubit.initialize();
        expect(cubit.state, AppThemeMode.auto);
        expect(logger.warningMessages, isNotEmpty);
      },
    );

    // The "corrupt persisted value" path (e.g. someone wrote 'foobar' to the
    // store) is collapsed to Success(null) by SecurePreferencesStore — the
    // warning is emitted at the storage layer (see
    // secure_preferences_store_test.dart). At the cubit, that path is
    // indistinguishable from "no persisted value": both emit auto silently.
    test(
      'initialize() with Success(null) emits auto without cubit-level warning',
      () async {
        final logger = _RecordingLogger();
        final cubit = _buildCubit(
          readResult: const Success(null),
          logger: logger,
        );
        await cubit.initialize();
        expect(cubit.state, AppThemeMode.auto);
        expect(logger.warningMessages, isEmpty);
      },
    );

    test('setMode(dark) persists dark to store', () async {
      final store = _FakePreferencesStore();
      final cubit = _buildCubit(store: store);
      await cubit.setMode(AppThemeMode.dark);
      expect(cubit.state, AppThemeMode.dark);
      expect(store.writtenThemeModes, [AppThemeMode.dark]);
    });

    test('setMode(currentState) is a no-op — no emit, no store write', () async {
      final store = _FakePreferencesStore();
      final cubit = _buildCubit(store: store);
      // initial state is auto; calling setMode(auto) is a no-op
      await cubit.setMode(AppThemeMode.auto);
      expect(store.writtenThemeModes, isEmpty);
    });

    test('write failure logs warning but still updates state', () async {
      final logger = _RecordingLogger();
      final cubit = _buildCubit(writeThemeFailure: true, logger: logger);
      await cubit.setMode(AppThemeMode.light);
      expect(cubit.state, AppThemeMode.light);
      expect(logger.warningMessages.single, contains('persist theme'));
    });

    testWidgets(
      'ThemeMode.system re-renders with opposite theme when OS brightness '
      'flips — no cubit involved',
      (tester) async {
        addTearDown(
          tester.platformDispatcher.clearPlatformBrightnessTestValue,
        );
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
        await tester.pumpWidget(
          MaterialApp(
            themeMode: ThemeMode.system,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: const _BrightnessLabel(),
          ),
        );
        expect(find.text('light'), findsOneWidget);

        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await tester.pumpAndSettle();
        expect(find.text('dark'), findsOneWidget);
      },
    );
  });
}

class _BrightnessLabel extends StatelessWidget {
  const _BrightnessLabel();

  @override
  Widget build(BuildContext context) {
    return Text(Theme.of(context).brightness.name);
  }
}

ThemeCubit _buildCubit({
  Result<AppThemeMode?>? readResult,
  _FakePreferencesStore? store,
  bool writeThemeFailure = false,
  _RecordingLogger? logger,
}) {
  final resolvedStore =
      store ??
      _FakePreferencesStore(
        readResult: readResult ?? const Success(null),
        writeThemeFailure: writeThemeFailure,
      );
  final resolvedLogger = logger ?? _RecordingLogger();
  return ThemeCubit.test(store: resolvedStore, log: resolvedLogger);
}

final class _FakePreferencesStore implements PreferencesStore {
  _FakePreferencesStore({
    this.readResult = const Success(null),
    this.writeThemeFailure = false,
  });

  final Result<AppThemeMode?> readResult;
  final bool writeThemeFailure;
  final writtenThemeModes = <AppThemeMode>[];

  @override
  Future<Result<AppThemeMode?>> readThemeMode() async => readResult;

  @override
  Future<Result<void>> writeThemeMode(AppThemeMode mode) async {
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
