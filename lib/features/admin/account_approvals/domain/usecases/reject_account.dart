import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../repositories/account_approvals_repository.dart';

@injectable
class RejectAccount {
  const RejectAccount(this._repository);

  final AccountApprovalsRepository _repository;

  /// [reason] must be non-empty (validated here as domain defence-in-depth;
  /// the SQL CHECK constraint is the second guard).
  Future<Result<void>> call({required String userId, required String reason}) {
    if (reason.trim().isEmpty) {
      return Future.value(
        const FailureResult(UnknownAdminError('rejection_reason_required')),
      );
    }
    return _repository.reject(userId: userId, reason: reason);
  }
}
