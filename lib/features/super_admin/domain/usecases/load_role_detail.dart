import 'package:injectable/injectable.dart';

import '../entities/role_detail.dart';
import '../repositories/role_catalog_repository.dart';

@injectable
class LoadRoleDetail {
  const LoadRoleDetail(this._repo);

  final RoleCatalogRepository _repo;

  Future<RoleDetail> call(String roleId) => _repo.loadRoleDetail(roleId);
}
