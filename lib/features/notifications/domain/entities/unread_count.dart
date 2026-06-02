// lib/features/notifications/domain/entities/unread_count.dart
//
// Phase 22 — Thin value wrapper returned by LoadUnreadCount use case.
// Keeps the unread badge driven by a typed entity rather than a raw int
// (avoids positional confusion with other integer use-cases).

/// Wraps the unread notification count returned by `unread_notification_count` RPC.
class UnreadCount {
  const UnreadCount(this.value);

  /// The raw unread count. Zero when no unread notifications.
  final int value;

  /// Convenience: `true` when there is at least one unread notification.
  bool get hasUnread => value > 0;

  @override
  String toString() => 'UnreadCount($value)';
}
