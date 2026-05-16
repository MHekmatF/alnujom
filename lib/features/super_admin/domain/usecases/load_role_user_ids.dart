import 'package:injectable/injectable.dart';

import '../repositories/role_catalog_repository.dart';

@injectable
class LoadRoleUserIds {
  const LoadRoleUserIds(this._repo);

  final RoleCatalogRepository _repo;

  Future<List<String>> call(String roleId) => _repo.loadUserIdsForRole(roleId);
}
