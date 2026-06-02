// lib/features/notifications/domain/repositories/notifications_repository.dart
//
// Phase 22 — Abstract contract for notification history access.
// Implemented by NotificationsRepositoryImpl (data layer).

import '../../../../core/errors/result.dart';
import '../entities/app_notification.dart';
import '../entities/unread_count.dart';

/// Repository for the `notifications` table.
///
/// All reads are self-scoped (RLS: `recipient_user_id = auth.uid()`).
/// Writes are RPC-only (no client INSERT/UPDATE/DELETE — R-182).
abstract interface class NotificationsRepository {
  /// Loads a page of notifications ordered by `created_at DESC`.
  ///
  /// Uses `limit`/`offset` pagination (FR-006).
  Future<Result<List<AppNotification>>> loadPage({
    int limit = 20,
    int offset = 0,
  });

  /// Marks a single notification as read via `mark_notification_read` RPC.
  Future<Result<void>> markRead(String id);

  /// Marks all own notifications as read via `mark_all_notifications_read` RPC.
  Future<Result<void>> markAllRead();

  /// Calls `unread_notification_count` RPC and returns the badge value.
  Future<Result<UnreadCount>> loadUnreadCount();
}
