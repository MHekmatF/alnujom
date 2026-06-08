// lib/features/inquiries/data/local/last_inquiry_phone_store.dart
//
// Phase 25 premium uplift — local-only memory of the last phone number an
// ANONYMOUS inquiry sender submitted, so the inquiry sheet can pre-fill it on
// the next open. Logged-in users prefill from their profile instead and never
// touch this store.
//
// Deliberately a tiny non-DI static helper (no @injectable / build_runner)
// wrapping flutter_secure_storage directly — mirrors the storage idiom used by
// RecentSearchesStorage / OnboardingSeenStorage but without the DI ceremony,
// since the inquiry sheet reads getIt lazily and a one-field value needs no
// graph wiring. All failures are swallowed (read → null, write → no-op) so a
// storage hiccup never blocks sending an inquiry.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Static helper persisting the most recent phone entered by an anonymous
/// inquiry sender. Single value, overwritten on each successful anonymous
/// submit.
abstract final class LastInquiryPhoneStore {
  static const _key = 'com.alnujom.inquiries.last_anonymous_phone_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Returns the last stored anonymous phone, or `null` when none is stored or
  /// on any read failure.
  static Future<String?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    } on Object {
      // Storage hiccup — behave as if nothing was remembered.
      return null;
    }
  }

  /// Persists [phone] (trimmed) as the last anonymous phone. No-op for a blank
  /// value or on any write failure.
  static Future<void> save(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return;
    try {
      await _storage.write(key: _key, value: trimmed);
    } on Object {
      // Swallow — remembering the phone is best-effort, never blocking.
    }
  }
}
