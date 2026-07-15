import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/settings/notification_prefs.dart';

/// Reads / writes the per-category notification-preference columns on
/// `user_preferences`. These columns are honored server-side by the
/// `dispatch_push` edge function (alongside the global `notifications_enabled`
/// mute), so writing them is what makes the Settings toggles actually suppress
/// pushes. Uses the global Supabase client (Constitution IX: Supabase confined
/// to data/); every method no-ops gracefully when signed out or on error, so the
/// local [NotificationPrefs] cache remains the fallback.
class NotificationPrefsRemote {
  const NotificationPrefsRemote();

  static const Map<NotificationCategory, String> _columns = {
    NotificationCategory.newMatches: 'notif_new_matches',
    NotificationCategory.messages: 'notif_messages',
    NotificationCategory.marketing: 'notif_marketing',
  };

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  /// The three category flags for the signed-in user. Empty when signed out or
  /// on error (the caller keeps the local defaults).
  Future<Map<NotificationCategory, bool>> read() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const {};
    try {
      final row = await _client
          .from('user_preferences')
          .select('notif_new_matches, notif_messages, notif_marketing')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return const {};
      return {
        for (final entry in _columns.entries)
          if (row[entry.value] is bool) entry.key: row[entry.value] as bool,
      };
    } on Object {
      return const {};
    }
  }

  /// Persists one category flag to the server (best-effort; no-ops signed out).
  Future<void> write(NotificationCategory category, bool value) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final column = _columns[category];
    if (column == null) return;
    try {
      await _client
          .from('user_preferences')
          .update({column: value})
          .eq('user_id', userId);
    } on Object {
      // Best-effort — the local flag still reflects the user's choice.
    }
  }
}
