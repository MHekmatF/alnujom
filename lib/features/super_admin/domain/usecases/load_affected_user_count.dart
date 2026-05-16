import 'package:injectable/injectable.dart';

import '../repositories/role_catalog_repository.dart';

@injectable
class LoadAffectedUserCount {
  const LoadAffectedUserCount(this._repo);

  final RoleCatalogRepository _repo;

  Future<int> call(String roleId) => _repo.loadAffectedUserCount(roleId);
}
