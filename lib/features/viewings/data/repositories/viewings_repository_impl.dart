// lib/features/viewings/data/repositories/viewings_repository_impl.dart
//
// Viewing scheduler — concrete [ViewingsRepository] delegating to
// [SupabaseViewingsDatasource].
//
// Principle IX: MUST NOT import supabase_flutter directly (the datasource is
// the sole importer). DTO→entity mapping needs the current user id to compute
// `amIPublisher`; the datasource exposes it.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/viewing.dart';
import '../../domain/repositories/viewings_repository.dart';
import '../datasources/supabase_viewings_datasource.dart';

@LazySingleton(as: ViewingsRepository)
class ViewingsRepositoryImpl implements ViewingsRepository {
  ViewingsRepositoryImpl(this._datasource);

  final SupabaseViewingsDatasource _datasource;

  @override
  Future<Result<List<Viewing>>> listMyViewings({
    DateTime? before,
    int limit = kViewingsPageSize,
  }) async {
    try {
      final uid = _datasource.currentUserId ?? '';
      final dtos = await _datasource.listMyViewings(before: before, limit: limit);
      return Success(dtos.map((d) => d.toEntity(uid)).toList());
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
        UnknownFailure('listMyViewings failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<String>> requestViewing({
    required String listingId,
    required DateTime scheduledAtUtc,
    String? note,
  }) async {
    try {
      final id = await _datasource.requestViewing(
        listingId: listingId,
        scheduledAtUtc: scheduledAtUtc,
        note: note,
      );
      return Success(id);
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
        UnknownFailure('requestViewing failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> updateStatus({
    required String viewingId,
    required String status,
  }) async {
    try {
      await _datasource.updateStatus(viewingId: viewingId, status: status);
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
        UnknownFailure('updateStatus failed: $e', cause: e, stackTrace: st),
      );
    }
  }
}
