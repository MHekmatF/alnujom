// lib/features/notifications/domain/usecases/load_unread_count.dart
//
// Phase 22 — Use case: load the unread notification count for the badge (R-193).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/unread_count.dart';
import '../repositories/notifications_repository.dart';

@injectable
class LoadUnreadCount {
  const LoadUnreadCount(this._repository);

  final NotificationsRepository _repository;

  Future<Result<UnreadCount>> call() => _repository.loadUnreadCount();
}
