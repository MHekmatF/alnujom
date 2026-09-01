// lib/core/network/secure_session_storage.dart
//
// QA E2E security hardening (auth H1) — persist the Supabase auth session
// (access token + long-lived REFRESH token) in the platform secure keystore
// instead of the supabase_flutter default, which writes the whole session —
// refresh token included — as plaintext into Android SharedPreferences.
//
// flutter_secure_storage maps to Android EncryptedSharedPreferences and the iOS
// Keychain, so the credential that can mint fresh access tokens is no longer
// readable by forensic extraction / another app on a rooted device.
//
// The app already uses `const FlutterSecureStorage()` as its single local-prefs
// mechanism (see recently_viewed_store.dart / secure_preferences_store.dart);
// we reuse the exact same construction here for consistency.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [LocalStorage] that persists the Supabase session in secure storage.
///
/// On first launch after the upgrade it performs a one-time migration: any
/// session previously written by supabase_flutter's default
/// [SharedPreferencesLocalStorage] is copied into secure storage and the
/// plaintext copy is deleted — so existing users are NOT logged out and no
/// readable token is left behind.
final class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({
    required this.legacyPersistSessionKey,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  /// The key supabase_flutter's default storage used in SharedPreferences
  /// (`sb-<projectRef>-auth-token`), so the one-time migration can find and
  /// clear the legacy plaintext session.
  final String legacyPersistSessionKey;
  final FlutterSecureStorage _storage;

  /// Secure-storage key holding the persisted session JSON.
  static const _key = 'com.alnujom.auth.session.v1';

  @override
  Future<void> initialize() async {
    // Best-effort one-time migration of any legacy plaintext session.
    // A failure here is harmless: the user simply signs in once more.
    try {
      final existing = await _storage.read(key: _key);
      if (existing != null && existing.isNotEmpty) return;

      final legacy = SharedPreferencesLocalStorage(
        persistSessionKey: legacyPersistSessionKey,
      );
      await legacy.initialize();
      if (await legacy.hasAccessToken()) {
        final session = await legacy.accessToken();
        if (session != null && session.isNotEmpty) {
          await _storage.write(key: _key, value: session);
        }
        // Remove the plaintext copy regardless, so no readable token lingers.
        await legacy.removePersistedSession();
      }
    } on Object {
      // Swallow: migration is optional; secure storage is the source of truth.
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    final value = await _storage.read(key: _key);
    return value != null && value.isNotEmpty;
  }

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);
}

/// A [GotrueAsyncStorage] for the PKCE code-verifier, backed by secure storage
/// (the default keeps it in plaintext SharedPreferences too).
final class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  SecureGotrueAsyncStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) => _storage.read(key: key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> removeItem({required String key}) => _storage.delete(key: key);
}
