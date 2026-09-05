// Plan A29 — block a person. Server-side: `block_user(p_user_id)`.
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/user_blocks_repository.dart';

@injectable
class BlockUser {
  const BlockUser(this._repository);

  final UserBlocksRepository _repository;

  Future<Result<void>> call(String userId) => _repository.block(userId);
}
