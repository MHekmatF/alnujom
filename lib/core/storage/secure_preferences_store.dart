import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../errors/failure.dart';
import '../errors/result.dart';
import '../logging/app_logger.dart';
import '../theme/color_palette.dart';
import '../theme/app_theme_mode.dart';
import 'preferences_keys.dart';
import 'preferences_store.dart';

@LazySingleton(as: PreferencesStore)
final class SecurePreferencesStore implements PreferencesStore {
  SecurePreferencesStore(AppLogger logger)
    : _logger = logger,
      _storage = const FlutterSecureStorage();

  @visibleForTesting
  SecurePreferencesStore.test(
    AppLogger logger, {
    required FlutterSecureStorage storage,
  }) : _logger = logger,
       _storage = storage;

  static const _themeKey = 'com.alnujom.preferences.theme_mode';
  static const _localeKey = 'com.alnujom.preferences.locale_code';
  static const _paletteKey = kPrefPalette;
  static const _tag = 'PreferencesStore';

  final AppLogger _logger;
  final FlutterSecureStorage _storage;

  @override
  Future<Result<AppThemeMode?>> readThemeMode() async {
    try {
      final raw = await _storage.read(key: _themeKey);
      return Success(_parseThemeMode(raw));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to read theme preference.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        CacheFailure(
          'Failed to read theme preference.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> writeThemeMode(AppThemeMode mode) async {
    try {
      await _storage.write(key: _themeKey, value: mode.name);
      return const Success(null);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to write theme preference.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        CacheFailure(
          'Failed to write theme preference.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<Locale?>> readLocale() async {
    try {
      final raw = await _storage.read(key: _localeKey);
      return Success(_parseLocale(raw));
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to read locale preference.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        CacheFailure(
          'Failed to read locale preference.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> writeLocale(Locale locale) async {
    try {
      await _storage.write(key: _localeKey, value: locale.languageCode);
      return const Success(null);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to write locale preference.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        CacheFailure(
          'Failed to write locale preference.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<String?>> readPaletteName() async {
    try {
      final raw = await _storage.read(key: _paletteKey);
      if (raw != null && raw.length > 32) {
        _warnUnrecognized('palette', raw);
        return const Success(null);
      }
      return Success(raw);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to read palette preference.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        CacheFailure(
          'Failed to read palette preference.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> writePalette(ColorPalette palette) async {
    try {
      await _storage.write(key: _paletteKey, value: palette.name);
      return const Success(null);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to write palette preference.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        CacheFailure(
          'Failed to write palette preference.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  AppThemeMode? _parseThemeMode(String? raw) {
    if (raw == null) return null;
    if (raw.length > 32) {
      _warnUnrecognized('theme mode', raw);
      return null;
    }
    return switch (raw) {
      'auto' => AppThemeMode.auto,
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => _warnAndReturnNull<AppThemeMode>('theme mode', raw),
    };
  }

  Locale? _parseLocale(String? raw) {
    if (raw == null) return null;
    if (raw.length > 32) {
      _warnUnrecognized('locale', raw);
      return null;
    }
    return switch (raw) {
      'ar' => const Locale('ar'),
      'en' => const Locale('en'),
      _ => _warnAndReturnNull<Locale>('locale', raw),
    };
  }

  T? _warnAndReturnNull<T>(String field, String raw) {
    _warnUnrecognized(field, raw);
    return null;
  }

  void _warnUnrecognized(String field, String raw) {
    _logger.warning('Ignoring unrecognized $field preference: $raw', tag: _tag);
  }
}
