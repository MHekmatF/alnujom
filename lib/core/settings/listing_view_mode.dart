import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Phase 035 — the user-switchable listing feed density, shown on Home and
/// Search results via the [ListingViewModeSwitcher].
///
/// * [comfortable] (مريح) — photo-first, one info line, big images.
/// * [balanced] (متوازن) — the default: medium card + specs + agent row.
/// * [compact] (مضغوط) — dense horizontal rows with a per-row WhatsApp button
///   (the most data-frugal option).
enum ListingViewMode { comfortable, balanced, compact }

/// App-wide persisted listing view mode. A pure process singleton mirroring
/// [LiteMode] — no provider-tree wiring. Any widget can react instantly via
/// `ValueListenableBuilder<ListingViewMode>(valueListenable: ListingViewMode..)`.
///
/// Persisted with [FlutterSecureStorage] (the app's preference store). Lazy
/// loads on first access of [notifier]; all storage ops swallow errors — the
/// view mode is a best-effort convenience, never a hard failure surface.
abstract final class ListingViewModePref {
  ListingViewModePref._();

  static const _storageKey = 'com.alnujom.settings.listing_view_mode';
  static const _default = ListingViewMode.balanced;

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static ValueNotifier<ListingViewMode>? _notifier;
  static bool _loaded = false;

  /// The reactive mode. Defaults to [balanced] until the persisted value loads.
  static ValueNotifier<ListingViewMode> get notifier {
    final existing = _notifier;
    if (existing != null) return existing;
    final created = ValueNotifier<ListingViewMode>(_default);
    _notifier = created;
    load();
    return created;
  }

  /// The current mode.
  static ListingViewMode get value => notifier.value;

  /// Loads the persisted mode into [notifier]. Safe to call repeatedly.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _storage.read(key: _storageKey);
      final value = _parse(raw);
      final target = _notifier ??= ValueNotifier<ListingViewMode>(_default);
      if (target.value != value) target.value = value;
    } on Object {
      // Best-effort: leave the mode at its default.
    }
  }

  /// Sets and persists the mode. Updates [notifier] immediately.
  static Future<void> set(ListingViewMode mode) async {
    _loaded = true;
    final target = _notifier ??= ValueNotifier<ListingViewMode>(_default);
    target.value = mode;
    try {
      await _storage.write(key: _storageKey, value: mode.name);
    } on Object {
      // Best-effort: the in-memory value still reflects the user's choice.
    }
  }

  static ListingViewMode _parse(String? raw) {
    return switch (raw) {
      'comfortable' => ListingViewMode.comfortable,
      'compact' => ListingViewMode.compact,
      _ => ListingViewMode.balanced,
    };
  }
}
