import '../entities/permission_catalog_entry.dart';
import '../entities/role_detail.dart';
import '../entities/role_mutation_result.dart';
import '../entities/role_with_counts.dart';

abstract class RoleCatalogRepository {
  Future<List<RoleWithCounts>> listRoles();
  Future<RoleDetail> loadRoleDetail(String roleId);
  Future<List<PermissionCatalogEntry>> loadPermissionCatalog();
  Future<RoleMutationResult> createRole({
    required String roleKey,
    required Map<String, String> displayName,
    required String? description,
    required List<String> permissionKeys,
  });
  Future<RoleMutationResult> updateRole({
    required String roleId,
    required Map<String, String> displayName,
    required String? description,
    required List<String> permissionKeys,
    required DateTime expectedUpdatedAt,
  });
  Future<void> deleteRole({
    required String roleId,
    required DateTime expectedUpdatedAt,
  });
  Future<int> loadAffectedUserCount(String roleId);
  Future<List<String>> loadUserIdsForRole(String roleId);
}
