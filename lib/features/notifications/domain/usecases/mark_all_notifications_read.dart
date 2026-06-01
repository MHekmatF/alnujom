// lib/features/notifications/domain/usecases/mark_all_notifications_read.dart
//
// Phase 22 — Use case: mark all of the caller's notifications as read (FR-008).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/notifications_repository.dart';

@injectable
class MarkAllNotificationsRead {
  const MarkAllNotificationsRead(this._repository);

  final NotificationsRepository _repository;

  Future<Result<void>> call() => _repository.markAllRead();
}
