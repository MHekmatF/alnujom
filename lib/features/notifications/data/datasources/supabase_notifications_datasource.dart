// lib/features/notifications/data/datasources/supabase_notifications_datasource.dart
//
// Phase 22 — Supabase I/O for the notifications feature.
//
// Principle IX: sole Supabase importer under `lib/features/notifications/`.
// All table/RPC names are string-keyed so PD compiles without the DB applied.
//
// Operations:
//   - `from('notifications')` paginated select (self-RLS scoped)
//   - `rpc('mark_notification_read')`
//   - `rpc('mark_all_notifications_read')`
//   - `rpc('unread_notification_count')`

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/app_notification_dto.dart';

@injectable
class SupabaseNotificationsDatasource {
  SupabaseNotificationsDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Loads a page of the caller's notifications, newest-first.
  ///
  /// Uses `range(offset, offset + limit - 1)` for offset pagination (FR-006).
  Future<List<AppNotificationDto>> loadPage({
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List<dynamic>)
        .map(
          (row) =>
              AppNotificationDto.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  /// Calls `mark_notification_read` RPC for a single notification.
  Future<void> markRead(String id) async {
    await _client.rpc('mark_notification_read', params: {'p_id': id});
  }

  /// Calls `mark_all_notifications_read` RPC — marks every unread notification
  /// for the signed-in user.
  Future<void> markAllRead() async {
    await _client.rpc('mark_all_notifications_read');
  }

  /// Calls `unread_notification_count` RPC.  Returns a non-negative integer.
  Future<int> loadUnreadCount() async {
    final result = await _client.rpc('unread_notification_count');
    return (result as num?)?.toInt() ?? 0;
  }
}
