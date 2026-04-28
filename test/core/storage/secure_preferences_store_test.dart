import 'package:alnujom/core/errors/failure.dart';
import 'package:alnujom/core/errors/result.dart';
import 'package:alnujom/core/logging/app_logger.dart';
import 'package:alnujom/core/storage/secure_preferences_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecurePreferencesStore', () {
    test('readThemeMode returns null when absent', () async {
      final store = SecurePreferencesStore.test(
        _RecordingLogger(),
        storage: _MemorySecureStorage(),
      );

      final result = await store.readThemeMode();

      expect(result, isA<Success<ThemeMode?>>());
      expect((result as Success<ThemeMode?>).value, isNull);
    });

    test('readThemeMode returns recognized dark value', () async {
      final storage = _MemorySecureStorage(
        values: {'com.alnujom.preferences.theme_mode': 'dark'},
      );
      final store = SecurePreferencesStore.test(
        _RecordingLogger(),
        storage: storage,
      );

      final result = await store.readThemeMode();

      expect(result, isA<Success<ThemeMode?>>());
      expect((result as Success<ThemeMode?>).value, ThemeMode.dark);
    });

    test(
      'readThemeMode tolerates unrecognized values and logs warning',
      () async {
        final logger = _RecordingLogger();
        final storage = _MemorySecureStorage(
          values: {'com.alnujom.preferences.theme_mode': 'foo'},
        );
        final store = SecurePreferencesStore.test(logger, storage: storage);

        final result = await store.readThemeMode();

        expect(result, isA<Success<ThemeMode?>>());
        expect((result as Success<ThemeMode?>).value, isNull);
        expect(
          logger.warningMessages.single,
          contains('unrecognized theme mode'),
        );
      },
    );

    test('writeThemeMode stores light value', () async {
      final storage = _MemorySecureStorage();
      final store = SecurePreferencesStore.test(
        _RecordingLogger(),
        storage: storage,
      );

      final result = await store.writeThemeMode(ThemeMode.light);

      expect(result, isA<Success<void>>());
      expect(storage.values['com.alnujom.preferences.theme_mode'], 'light');
    });

    test('writeThemeMode errors return CacheFailure', () async {
      final store = SecurePreferencesStore.test(
        _RecordingLogger(),
        storage: _MemorySecureStorage(throwOnWrite: true),
      );

      final result = await store.writeThemeMode(ThemeMode.dark);

      expect(result, isA<FailureResult<void>>());
      expect((result as FailureResult<void>).failure, isA<CacheFailure>());
    });
  });
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

final class _MemorySecureStorage extends Fake implements FlutterSecureStorage {
  _MemorySecureStorage({Map<String, String>? values, this.throwOnWrite = false})
    : values = Map.of(values ?? const {});

  final Map<String, String> values;
  final bool throwOnWrite;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnWrite) {
      throw StateError('write failed');
    }
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}
