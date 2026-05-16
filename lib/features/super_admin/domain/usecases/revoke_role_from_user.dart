import 'package:injectable/injectable.dart';

import '../entities/role_assignment_result.dart';
import '../repositories/user_search_repository.dart';

@injectable
class RevokeRoleFromUser {
  const RevokeRoleFromUser(this._repo);

  final UserSearchRepository _repo;

  Future<RoleAssignmentResult> call({
    required String targetUserId,
    required String targetRoleId,
  }) {
    return _repo.revoke(targetUserId: targetUserId, targetRoleId: targetRoleId);
  }
}
