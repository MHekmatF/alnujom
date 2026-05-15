import 'package:injectable/injectable.dart';

import '../../domain/entities/assigned_role.dart';
import '../repositories/profile_repository.dart';

@injectable
class LoadAssignedRoles {
  const LoadAssignedRoles(this._repository);

  final ProfileRepository _repository;

  Future<List<AssignedRole>> call(String localeCode) =>
      _repository.loadAssignedRoles(localeCode);
}
