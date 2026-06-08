import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App-wide "Data saver" (lite / low-data) flag for the Syrian low-bandwidth
/// reality.
///
/// A pure process singleton — NO provider-tree / root / main.dart wiring. The
/// current value is exposed as a `ValueNotifier<bool>` so any widget can
/// `ValueListenableBuilder` on it and react instantly when the user flips the
/// toggle:
///
/// ```dart
/// ValueListenableBuilder<bool>(
///   valueListenable: LiteMode.notifier,
///   builder: (context, lite, _) => ...,
/// )
/// ```
///
/// The flag is persisted with [FlutterSecureStorage] (mirroring the rest of the
/// app's preference storage). It lazy-loads from disk on first access of
/// [notifier], and the settings screen can call [load] explicitly to warm it.
/// All storage operations swallow their errors — Data saver is a best-effort
/// convenience, never a hard failure surface.
abstract final class LiteMode {
  LiteMode._();

  static const _storageKey = 'com.alnujom.settings.lite_mode';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static ValueNotifier<bool>? _notifier;
  static bool _loaded = false;

  /// The reactive flag. Defaults to `false` (Data saver OFF) until the
  /// persisted value loads. Accessing it kicks off a lazy load on first use.
  static ValueNotifier<bool> get notifier {
    final existing = _notifier;
    if (existing != null) return existing;
    final created = ValueNotifier<bool>(false);
    _notifier = created;
    // Fire-and-forget lazy load; the notifier updates when disk resolves.
    load();
    return created;
  }

  /// Whether Data saver is currently ON.
  static bool get isOn => notifier.value;

  /// Loads the persisted flag from secure storage into [notifier]. Safe to call
  /// repeatedly — only reads disk once. The settings screen calls this so the
  /// toggle reflects the saved state on open. Errors are swallowed (treated as
  /// OFF).
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _storage.read(key: _storageKey);
      final value = raw == 'true';
      final target = _notifier ??= ValueNotifier<bool>(false);
      if (target.value != value) target.value = value;
    } on Object {
      // Best-effort: leave the flag at its default (OFF).
    }
  }

  /// Sets and persists the Data saver flag. Updates [notifier] immediately so
  /// listeners react without waiting on disk; the write is best-effort and its
  /// errors are swallowed.
  static Future<void> set(bool value) async {
    _loaded = true;
    final target = _notifier ??= ValueNotifier<bool>(false);
    target.value = value;
    try {
      await _storage.write(key: _storageKey, value: value ? 'true' : 'false');
    } on Object {
      // Best-effort: the in-memory flag still reflects the user's choice.
    }
  }
}
