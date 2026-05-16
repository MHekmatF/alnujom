import 'package:injectable/injectable.dart';

import '../entities/role_assignment_summary.dart';
import '../repositories/user_search_repository.dart';

@injectable
class LoadUserAssignments {
  const LoadUserAssignments(this._repo);

  final UserSearchRepository _repo;

  Future<List<RoleAssignmentSummary>> call(String userId) {
    return _repo.loadUserAssignments(userId);
  }
}
