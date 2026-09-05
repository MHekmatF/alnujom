// Plan A29 — everyone the signed-in user has blocked. Server-side:
// `list_my_blocks()`.
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/blocked_user.dart';
import '../repositories/user_blocks_repository.dart';

@injectable
class LoadBlockedUsers {
  const LoadBlockedUsers(this._repository);

  final UserBlocksRepository _repository;

  Future<Result<List<BlockedUser>>> call() => _repository.listBlocked();
}
