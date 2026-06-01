// lib/features/notifications/domain/entities/app_notification.dart
//
// Phase 22 — Domain entity for a row from `public.notifications`.

import 'notification_type.dart';

/// Immutable domain representation of one row from `public.notifications`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.params,
    required this.createdAt,
    this.readAt,
  });

  /// UUID primary key.
  final String id;

  /// Parsed notification type (six values — FR-001).
  final NotificationType type;

  /// Associated UUIDs from the `params` jsonb column.
  /// No free-text PII — only IDs (FR-004).
  final Map<String, dynamic> params;

  /// `null` means the notification has not been read yet.
  final DateTime? readAt;

  final DateTime createdAt;

  /// Convenience getter: `true` when [readAt] is `null`.
  bool get isUnread => readAt == null;

  @override
  String toString() =>
      'AppNotification(id: $id, type: ${type.key}, isUnread: $isUnread)';
}
