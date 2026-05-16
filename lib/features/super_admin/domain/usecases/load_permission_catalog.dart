import 'package:injectable/injectable.dart';

import '../entities/permission_catalog_entry.dart';
import '../repositories/role_catalog_repository.dart';

@injectable
class LoadPermissionCatalog {
  const LoadPermissionCatalog(this._repo);

  final RoleCatalogRepository _repo;

  Future<List<PermissionCatalogEntry>> call() => _repo.loadPermissionCatalog();
}
