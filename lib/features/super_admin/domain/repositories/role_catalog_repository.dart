import '../entities/permission_catalog_entry.dart';
import '../entities/role_detail.dart';
import '../entities/role_with_counts.dart';

abstract class RoleCatalogRepository {
  Future<List<RoleWithCounts>> listRoles();
  Future<RoleDetail> loadRoleDetail(String roleId);
  Future<List<PermissionCatalogEntry>> loadPermissionCatalog();
}
