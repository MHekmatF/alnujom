// lib/features/notifications/presentation/bloc/notification_badge_cubit.dart
//
// Phase 22 PN (T029) — Singleton Cubit tracking unread notification count.
// Refresh on mount + foreground-resume + when the push listener signals a
// foreground message.  NOT a Realtime subscription (R-193).

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/usecases/load_unread_count.dart';

part 'notification_badge_state.dart';

@lazySingleton
class NotificationBadgeCubit extends Cubit<NotificationBadgeState> {
  NotificationBadgeCubit(this._loadUnreadCount)
      : super(const NotificationBadgeState(count: 0));

  final LoadUnreadCount _loadUnreadCount;

  /// Re-fetches the unread count.  Called on mount, foreground-resume, and
  /// when the push listener delivers a foreground message (FR-014 / R-193).
  Future<void> refresh() async {
    final result = await _loadUnreadCount();
    if (result is Success) {
      emit(NotificationBadgeState(count: (result as Success).value.value));
    }
    // On failure: silently retain the previous count.
  }

  /// Optimistically decrements the badge by 1 (called when the center marks
  /// a single notification read).
  void decrement() {
    final next = (state.count - 1).clamp(0, double.maxFinite.toInt());
    emit(NotificationBadgeState(count: next));
  }

  /// Resets to zero (called after mark-all-read).
  void clear() => emit(const NotificationBadgeState(count: 0));
}
