import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../repositories/account_approvals_repository.dart';

@injectable
class ApproveAccount {
  const ApproveAccount(this._repository);

  final AccountApprovalsRepository _repository;

  Future<Result<void>> call({required String userId}) =>
      _repository.approve(userId: userId);
}
