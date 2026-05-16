import '../entities/role_assignment_result.dart';
import '../entities/role_assignment_summary.dart';
import '../entities/user_search_result.dart';

abstract class UserSearchRepository {
  Future<List<UserSearchResult>> searchUsers(String query);
  Future<List<RoleAssignmentSummary>> loadUserAssignments(String userId);
  Future<RoleAssignmentResult> assign({
    required String targetUserId,
    required String targetRoleId,
    String? confirmationToken,
  });
  Future<RoleAssignmentResult> revoke({
    required String targetUserId,
    required String targetRoleId,
  });
}
