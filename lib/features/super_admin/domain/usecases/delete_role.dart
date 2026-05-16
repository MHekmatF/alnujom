import 'package:injectable/injectable.dart';

import '../repositories/role_catalog_repository.dart';

@injectable
class DeleteRole {
  const DeleteRole(this._repo);

  final RoleCatalogRepository _repo;

  Future<void> call({
    required String roleId,
    required DateTime expectedUpdatedAt,
  }) {
    return _repo.deleteRole(
      roleId: roleId,
      expectedUpdatedAt: expectedUpdatedAt,
    );
  }
}
