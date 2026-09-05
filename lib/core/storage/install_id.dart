import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// A random id minted once per install and kept in secure storage (plan A35).
///
/// It exists so a signed-out person opening a listing counts as one viewer,
/// not one view per open. It is 32 hex characters of `Random.secure()`, it
/// says nothing about the phone or the person, it never leaves the device
/// except as the `p_viewer_key` of `record_listing_view`, and it goes away
/// with the app's data. A signed-in person is keyed on their account instead;
/// the RPC prefers that when both are present.
///
/// Every failure returns `null`, and `null` simply means "not counted".
@lazySingleton
class InstallId {
  InstallId() : _storage = const FlutterSecureStorage();

  static const _key = 'com.alnujom.device.install_id';
  static final _shape = RegExp(r'^[a-f0-9]{32}$');

  final FlutterSecureStorage _storage;
  String? _cached;

  Future<String?> get() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final existing = await _storage.read(key: _key);
      if (existing != null && _shape.hasMatch(existing)) {
        _cached = existing;
        return existing;
      }
      final fresh = _mint();
      await _storage.write(key: _key, value: fresh);
      _cached = fresh;
      return fresh;
    } on Object {
      return null;
    }
  }

  static String _mint() {
    final rng = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(rng.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }
}
