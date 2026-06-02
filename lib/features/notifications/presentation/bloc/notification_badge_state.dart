// lib/features/notifications/presentation/bloc/notification_badge_state.dart
part of 'notification_badge_cubit.dart';

final class NotificationBadgeState extends Equatable {
  const NotificationBadgeState({required this.count});

  /// Number of unread notifications. Zero when none.
  final int count;

  bool get hasUnread => count > 0;

  @override
  List<Object?> get props => [count];
}
