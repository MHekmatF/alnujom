// lib/features/notifications/data/repositories/notifications_repository_impl.dart
//
// Phase 22 — Concrete [NotificationsRepository] delegating to
// [SupabaseNotificationsDatasource].
//
// Principle IX: MUST NOT import supabase_flutter directly beyond
// [PostgrestException] (typed error-code mapping only).

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/unread_count.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/supabase_notifications_datasource.dart';

@LazySingleton(as: NotificationsRepository)
class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._datasource);

  final SupabaseNotificationsDatasource _datasource;

  @override
  Future<Result<List<AppNotification>>> loadPage({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final dtos = await _datasource.loadPage(limit: limit, offset: offset);
      return Success(dtos.map((d) => d.toEntity()).toList());
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadPage failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> markRead(String id) async {
    try {
      await _datasource.markRead(id);
      return const Success(null);
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('markRead failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> markAllRead() async {
    try {
      await _datasource.markAllRead();
      return const Success(null);
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('markAllRead failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<UnreadCount>> loadUnreadCount() async {
    try {
      final count = await _datasource.loadUnreadCount();
      return Success(UnreadCount(count));
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadUnreadCount failed: $e', cause: e, stackTrace: st),
      );
    }
  }
}
