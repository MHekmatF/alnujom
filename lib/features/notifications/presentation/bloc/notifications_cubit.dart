// lib/features/notifications/presentation/bloc/notifications_cubit.dart
//
// Phase 22 PN (T028) — NotificationsCubit: drives the notification center page.
// States: loading / list / paginating / error.  Drives LoadNotifications,
// MarkNotificationRead, MarkAllNotificationsRead.  Bounded pagination.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/usecases/load_notifications.dart';
import '../../domain/usecases/mark_all_notifications_read.dart';
import '../../domain/usecases/mark_notification_read.dart';

part 'notifications_state.dart';

/// Page size used for bounded pagination (FR-006).
const int _kPageSize = 20;

@injectable
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(
    this._loadNotifications,
    this._markRead,
    this._markAllRead,
  ) : super(const NotificationsState.initial());

  final LoadNotifications _loadNotifications;
  final MarkNotificationRead _markRead;
  final MarkAllNotificationsRead _markAllRead;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Initial load — replaces any prior state.
  Future<void> load() async {
    emit(const NotificationsState.loading());
    final result = await _loadNotifications(limit: _kPageSize, offset: 0);
    switch (result) {
      case Success(:final value):
        emit(NotificationsState.list(
          notifications: value,
          hasMore: value.length == _kPageSize,
          offset: value.length,
        ));
      case FailureResult():
        emit(const NotificationsState.error());
    }
  }

  /// Load the next page (called from scroll listener).
  Future<void> loadMore() async {
    final current = state;
    if (current.status != NotificationsStatus.list) return;
    if (!current.hasMore) return;
    if (current.isPaginating) return;

    emit(current.copyWith(isPaginating: true));
    final result = await _loadNotifications(
      limit: _kPageSize,
      offset: current.offset,
    );
    switch (result) {
      case Success(:final value):
        emit(current.copyWith(
          notifications: [...current.notifications, ...value],
          hasMore: value.length == _kPageSize,
          offset: current.offset + value.length,
          isPaginating: false,
        ));
      case FailureResult():
        // Keep existing list; pagination failure is silent (no full error state).
        emit(current.copyWith(isPaginating: false));
    }
  }

  /// Mark a single notification read — optimistically updates UI.
  Future<void> markRead(String notificationId) async {
    final current = state;
    if (current.status != NotificationsStatus.list) return;
    // Optimistic update.
    final updated = current.notifications.map((n) {
      if (n.id != notificationId) return n;
      // Re-create with a non-null readAt so isUnread becomes false.
      return AppNotification(
        id: n.id,
        type: n.type,
        params: n.params,
        createdAt: n.createdAt,
        readAt: DateTime.now(),
      );
    }).toList();
    emit(current.copyWith(notifications: updated));
    // Fire-and-forget RPC; we already updated UI.
    await _markRead(notificationId);
  }

  /// Mark all notifications read — optimistically updates UI.
  Future<void> markAllRead() async {
    final current = state;
    if (current.status != NotificationsStatus.list) return;
    final now = DateTime.now();
    final updated = current.notifications.map((n) {
      if (!n.isUnread) return n;
      return AppNotification(
        id: n.id,
        type: n.type,
        params: n.params,
        createdAt: n.createdAt,
        readAt: now,
      );
    }).toList();
    emit(current.copyWith(notifications: updated));
    await _markAllRead();
  }

  /// Called by the push listener on foreground push — refreshes the list.
  Future<void> refresh() => load();
}
