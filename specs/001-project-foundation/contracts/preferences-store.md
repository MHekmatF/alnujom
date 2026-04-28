# Contract: PreferencesStore

**Layer**: `lib/core/storage/`
**Spec requirement**: FR-006, FR-016
**Library**: `flutter_secure_storage` (research.md Decision 6)
**Data model**: see [data-model.md](../data-model.md) — entity "User Preferences (local)"

## Purpose

A thin, project-defined interface around device-local persistence for the user's theme and locale choices. By going through this interface, `ThemeCubit`/`LocaleCubit` (and future Phase 5 auth-token persistence) never touch `flutter_secure_storage` directly — a v2 storage swap edits one impl file.

## Public surface

```dart
// lib/core/storage/preferences_store.dart

abstract interface class PreferencesStore {
  /// Returns the persisted theme mode, or null if the user has never made an explicit choice.
  /// (FR-016 distinguishes absent ↔ explicit.)
  Future<Result<ThemeMode?>> readThemeMode();
  Future<Result<void>> writeThemeMode(ThemeMode mode);

  /// Returns the persisted locale, or null if absent. First-launch default is Arabic and
  /// is NOT persisted until the user toggles (FR-005, FR-006).
  Future<Result<Locale?>> readLocale();
  Future<Result<void>> writeLocale(Locale locale);
}
```

`ThemeMode` is `flutter`'s built-in enum (`system | light | dark`). `Locale` is `dart:ui`'s `Locale` value type. These are not Supabase types and are safe to expose at this boundary.

## Implementation

```dart
// lib/core/storage/secure_preferences_store.dart

@LazySingleton(as: PreferencesStore)
final class SecurePreferencesStore implements PreferencesStore {
  final FlutterSecureStorage _storage;
  final AppLogger _logger;

  static const _themeKey = 'com.alnujom.preferences.theme_mode';
  static const _localeKey = 'com.alnujom.preferences.locale_code';

  @override
  Future<Result<ThemeMode?>> readThemeMode() async {
    try {
      final raw = await _storage.read(key: _themeKey);
      return Success(_parseThemeMode(raw)); // null if absent or unrecognized
    } catch (e, s) {
      _logger.warning('readThemeMode failed', error: e, stackTrace: s, tag: 'PreferencesStore');
      return FailureResult(CacheFailure('Failed to read theme', cause: e, stackTrace: s));
    }
  }
  // ... similar for write + locale
}
```

## Validation rules (mirror data-model.md)

- Read: tolerate any unrecognized stored value; return `Success(null)` and log a `warning`.
- Write: errors return `FailureResult(CacheFailure)`; the caller (cubit) keeps the in-memory state and logs a warning.
- Stored values are short ASCII strings (`'system'`, `'light'`, `'dark'`, `'ar'`, `'en'`). Any value > 32 bytes is logged as a `warning`.

## Wire-up

- `injection.dart` registers `PreferencesStore` → `SecurePreferencesStore` lazy-singleton. The `FlutterSecureStorage` instance is constructed inside `SecurePreferencesStore` with default Android options.
- `main.dart` reads both keys at startup and passes initial values to `ThemeCubit` and `LocaleCubit` constructors.

## Phase 1 verification

- `test/core/storage/secure_preferences_store_test.dart` uses a fake `FlutterSecureStorage` (mockito-generated) and covers:
  - read returns `Success(null)` for absent
  - read returns `Success(ThemeMode.dark)` for stored `'dark'`
  - read returns `Success(null)` (with a logged warning) for stored `'foo'`
  - write success
  - write error → `FailureResult(CacheFailure)` with the underlying cause attached
- Manual: install the debug APK on the Infinix Note 8, toggle theme/locale, force-stop the app, relaunch — preferences are restored (FR-006 acceptance).
