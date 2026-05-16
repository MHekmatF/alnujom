import 'package:injectable/injectable.dart';

import '../entities/role_with_counts.dart';
import '../repositories/role_catalog_repository.dart';

@injectable
class ListRoles {
  const ListRoles(this._repo);

  final RoleCatalogRepository _repo;

  Future<List<RoleWithCounts>> call() => _repo.listRoles();
}
