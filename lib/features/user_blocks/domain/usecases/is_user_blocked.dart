// Plan A29 — whether the signed-in user has blocked a person. Server-side:
// `is_user_blocked_by_me(p_user_id)`.
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/user_blocks_repository.dart';

@injectable
class IsUserBlocked {
  const IsUserBlocked(this._repository);

  final UserBlocksRepository _repository;

  Future<Result<bool>> call(String userId) => _repository.isBlocked(userId);
}
