import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../../core/errors/result.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../domain/entities/account_approval_request.dart';
import '../../domain/repositories/account_approvals_repository.dart';
import '../datasources/supabase_account_approvals_datasource.dart';

@LazySingleton(as: AccountApprovalsRepository)
class AccountApprovalsRepositoryImpl implements AccountApprovalsRepository {
  AccountApprovalsRepositoryImpl(this._ds, this._logger);

  static const _tag = 'AccountApprovalsRepositoryImpl';

  final SupabaseAccountApprovalsDatasource _ds;
  final AppLogger _logger;

  @override
  Future<Result<List<AccountApprovalRequest>>> loadPendingQueue({
    DateTime? before,
    int limit = kApprovalsPageSize,
  }) async {
    try {
      final list = await _ds.loadPendingQueue(before: before, limit: limit);
      return Success(list);
    } on Object catch (error, stackTrace) {
      return FailureResult(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> approve({required String userId}) async {
    try {
      await _ds.approve(userId: userId);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      if (error.code == '02000') {
        return FailureResult(
          RequestAlreadyResolved(cause: error, stackTrace: stackTrace),
        );
      }
      if (error.code == '42501') {
        return FailureResult(
          AdminForbidden(cause: error, stackTrace: stackTrace),
        );
      }
      return FailureResult(_mapError(error, stackTrace));
    } on Object catch (error, stackTrace) {
      return FailureResult(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> reject({
    required String userId,
    required String reason,
  }) async {
    try {
      await _ds.reject(userId: userId, reason: reason);
      return const Success(null);
    } on PostgrestException catch (error, stackTrace) {
      if (error.code == '02000') {
        return FailureResult(
          RequestAlreadyResolved(cause: error, stackTrace: stackTrace),
        );
      }
      if (error.code == '42501') {
        return FailureResult(
          AdminForbidden(cause: error, stackTrace: stackTrace),
        );
      }
      return FailureResult(_mapError(error, stackTrace));
    } on Object catch (error, stackTrace) {
      return FailureResult(_mapError(error, stackTrace));
    }
  }

  AccountApprovalsFailure _mapError(Object error, StackTrace stackTrace) {
    _logger.warning(
      'Admin approvals data error.',
      error: error,
      stackTrace: stackTrace,
      tag: _tag,
    );
    return UnknownAdminError(
      error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
