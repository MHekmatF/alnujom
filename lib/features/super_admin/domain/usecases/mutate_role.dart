import 'package:injectable/injectable.dart';

import '../entities/role_mutation_result.dart';
import '../repositories/role_catalog_repository.dart';

@injectable
class MutateRole {
  const MutateRole(this._repo);

  final RoleCatalogRepository _repo;

  Future<RoleMutationResult> call(MutateRoleParams params) {
    return switch (params) {
      CreateRoleParams() => _repo.createRole(
        roleKey: params.roleKey,
        displayName: params.displayName,
        description: params.description,
        permissionKeys: params.permissionKeys,
      ),
      UpdateRoleParams() => _repo.updateRole(
        roleId: params.roleId,
        displayName: params.displayName,
        description: params.description,
        permissionKeys: params.permissionKeys,
        expectedUpdatedAt: params.expectedUpdatedAt,
      ),
    };
  }
}
