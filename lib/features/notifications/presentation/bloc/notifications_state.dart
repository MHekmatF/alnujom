// lib/features/notifications/presentation/bloc/notifications_state.dart
part of 'notifications_cubit.dart';

enum NotificationsStatus { initial, loading, list, error }

final class NotificationsState extends Equatable {
  const NotificationsState._({
    required this.status,
    this.notifications = const [],
    this.hasMore = false,
    this.offset = 0,
    this.isPaginating = false,
  });

  const NotificationsState.initial()
    : this._(status: NotificationsStatus.initial);

  const NotificationsState.loading()
    : this._(status: NotificationsStatus.loading);

  const NotificationsState.list({
    required List<AppNotification> notifications,
    required bool hasMore,
    required int offset,
  }) : this._(
         status: NotificationsStatus.list,
         notifications: notifications,
         hasMore: hasMore,
         offset: offset,
       );

  const NotificationsState.error() : this._(status: NotificationsStatus.error);

  final NotificationsStatus status;
  final List<AppNotification> notifications;
  final bool hasMore;
  final int offset;

  /// True while a secondary page load is in progress (NOT the initial load).
  final bool isPaginating;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? hasMore,
    int? offset,
    bool? isPaginating,
  }) {
    return NotificationsState._(
      status: status,
      notifications: notifications ?? this.notifications,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      isPaginating: isPaginating ?? this.isPaginating,
    );
  }

  @override
  List<Object?> get props => [
    status,
    notifications,
    hasMore,
    offset,
    isPaginating,
  ];
}
