import 'package:injectable/injectable.dart';

import '../entities/role_assignment_result.dart';
import '../repositories/user_search_repository.dart';

@injectable
class AssignRoleToUser {
  const AssignRoleToUser(this._repo);

  final UserSearchRepository _repo;

  Future<RoleAssignmentResult> call({
    required String targetUserId,
    required String targetRoleId,
    String? confirmationToken,
  }) {
    return _repo.assign(
      targetUserId: targetUserId,
      targetRoleId: targetRoleId,
      confirmationToken: confirmationToken,
    );
  }
}
