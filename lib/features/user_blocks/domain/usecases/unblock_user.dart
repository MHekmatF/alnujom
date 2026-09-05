// Plan A29 — lift a block. Server-side: `unblock_user(p_user_id)`.
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/user_blocks_repository.dart';

@injectable
class UnblockUser {
  const UnblockUser(this._repository);

  final UserBlocksRepository _repository;

  Future<Result<void>> call(String userId) => _repository.unblock(userId);
}
