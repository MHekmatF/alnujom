// lib/features/notifications/domain/usecases/load_notifications.dart
//
// Phase 22 — Use case: load a paginated page of the caller's notifications.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/app_notification.dart';
import '../repositories/notifications_repository.dart';

@injectable
class LoadNotifications {
  const LoadNotifications(this._repository);

  final NotificationsRepository _repository;

  Future<Result<List<AppNotification>>> call({
    int limit = 20,
    int offset = 0,
  }) => _repository.loadPage(limit: limit, offset: offset);
}
