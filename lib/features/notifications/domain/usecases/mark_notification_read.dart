// lib/features/notifications/domain/usecases/mark_notification_read.dart
//
// Phase 22 — Use case: mark a single notification as read (FR-008).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/notifications_repository.dart';

@injectable
class MarkNotificationRead {
  const MarkNotificationRead(this._repository);

  final NotificationsRepository _repository;

  Future<Result<void>> call(String notificationId) =>
      _repository.markRead(notificationId);
}
