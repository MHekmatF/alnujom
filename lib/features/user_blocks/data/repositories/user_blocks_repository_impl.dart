// Plan A29 — UserBlocksRepository over the four block RPCs.
import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/blocked_user.dart';
import '../../domain/repositories/user_blocks_repository.dart';
import '../datasources/supabase_user_blocks_datasource.dart';

@LazySingleton(as: UserBlocksRepository)
class UserBlocksRepositoryImpl implements UserBlocksRepository {
  UserBlocksRepositoryImpl(this._datasource);

  final SupabaseUserBlocksDatasource _datasource;

  @override
  Future<Result<void>> block(String userId) =>
      _guard('block', () => _datasource.block(userId));

  @override
  Future<Result<void>> unblock(String userId) =>
      _guard('unblock', () => _datasource.unblock(userId));

  @override
  Future<Result<bool>> isBlocked(String userId) =>
      _guard('isBlocked', () => _datasource.isBlocked(userId));

  @override
  Future<Result<List<BlockedUser>>> listBlocked() => _guard('listBlocked', () async {
    final rows = await _datasource.listBlocked();
    return rows
        .map(
          (r) => BlockedUser(
            userId: r['user_id'] as String,
            fullName: r['full_name'] as String?,
            blockedAt: DateTime.parse(r['blocked_at'] as String),
          ),
        )
        .toList();
  });

  Future<Result<T>> _guard<T>(String op, Future<T> Function() body) async {
    try {
      return Success(await body());
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
        UnknownFailure('$op failed: $e', cause: e, stackTrace: st),
      );
    }
  }
}
