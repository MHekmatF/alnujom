import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../entities/account_approval_request.dart';
import '../repositories/account_approvals_repository.dart';

@injectable
class LoadPendingQueue {
  const LoadPendingQueue(this._repository);

  final AccountApprovalsRepository _repository;

  Future<Result<List<AccountApprovalRequest>>> call({
    DateTime? before,
    int limit = kApprovalsPageSize,
  }) => _repository.loadPendingQueue(before: before, limit: limit);
}
