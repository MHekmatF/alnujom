import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The user-facing notification categories surfaced on the Settings screen.
///
/// Each maps to one or more of the app's `NotificationType`s:
/// - [newMatches]  → `saved_search_match` (a new listing matches a saved search)
/// - [messages]    → `inquiry_received` + `agency_invitation` (someone reached out)
/// - [marketing]   → promotional / marketing pushes (reserved — no such type ships
///   today, so this preference is stored for when promos are introduced)
///
/// Transactional notifications (account/listing approval + rejection) are always
/// delivered and are intentionally not user-muteable.
enum NotificationCategory { newMatches, messages, marketing }

/// Per-category notification on/off preferences.
///
/// A pure process singleton mirroring [LiteMode] — NO provider-tree wiring. Each
/// category exposes a `ValueNotifier<bool>` so any widget can
/// `ValueListenableBuilder` on it and react instantly. Values persist with
/// [FlutterSecureStorage] (best-effort; storage errors are swallowed).
///
/// Defaults: [newMatches] ON, [messages] ON, [marketing] OFF.
abstract final class NotificationPrefs {
  NotificationPrefs._();

  static const _keyPrefix = 'com.alnujom.settings.notif.';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static final Map<NotificationCategory, ValueNotifier<bool>> _notifiers = {};
  static bool _loaded = false;

  static bool _defaultFor(NotificationCategory category) =>
      category != NotificationCategory.marketing;

  /// The reactive flag for [category]. Reflects the persisted value once
  /// [load] resolves; until then it holds the default. The first access creates
  /// every category's notifier and kicks off a lazy load.
  static ValueNotifier<bool> notifier(NotificationCategory category) {
    // Create the ONE notifier being asked for, rather than assuming the map is
    // either empty or complete.
    //
    // It used to populate every category only when `_notifiers.isEmpty`, then
    // return `_notifiers[category]!`. But `load()` awaits secure storage INSIDE
    // its loop, so the moment it reads the first category it yields — leaving
    // the map non-empty and missing the rest. A build in that window skipped the
    // population branch and the `!` threw on the next category.
    //
    // That is not a rare race: it is what happens every time the Settings screen
    // opens, because it calls `load()` in initState and reads the notifiers in
    // the very next build. Settings crashed for everyone, and in release it was
    // a blank grey screen with nothing in the log. Found on the Infinix Note 8,
    // 2026-09-02.
    final existing = _notifiers[category];
    if (existing != null) return existing;
    final created = _notifiers[category] = ValueNotifier<bool>(
      _defaultFor(category),
    );
    // Fire-and-forget lazy load; notifiers update when disk resolves. Safe to
    // call repeatedly — `load()` returns early once it has run.
    load();
    return created;
  }

  /// Whether [category] is currently ON.
  static bool isOn(NotificationCategory category) => notifier(category).value;

  /// Loads the persisted flags into their notifiers. Safe to call repeatedly —
  /// only reads disk once. Errors are swallowed (categories keep their default).
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    for (final c in NotificationCategory.values) {
      final target = _notifiers[c] ??= ValueNotifier<bool>(_defaultFor(c));
      try {
        final raw = await _storage.read(key: '$_keyPrefix${c.name}');
        if (raw == null) continue; // no stored value → keep default
        final value = raw == 'true';
        if (target.value != value) target.value = value;
      } on Object {
        // Best-effort: leave the flag at its default.
      }
    }
  }

  /// Sets and persists [category]. Updates the notifier immediately so listeners
  /// react without waiting on disk; the write is best-effort.
  static Future<void> set(NotificationCategory category, bool value) async {
    _loaded = true;
    final target = _notifiers[category] ??= ValueNotifier<bool>(
      _defaultFor(category),
    );
    target.value = value;
    try {
      await _storage.write(
        key: '$_keyPrefix${category.name}',
        value: value ? 'true' : 'false',
      );
    } on Object {
      // Best-effort: the in-memory flag still reflects the user's choice.
    }
  }
}
