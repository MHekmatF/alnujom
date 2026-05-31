// Phase 19 (spec/019-agencies) — T040
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../repositories/agencies_admin_repository.dart';

@injectable
class SuspendAgency {
  const SuspendAgency(this._repository);

  final AgenciesAdminRepository _repository;

  Future<Result<void>> call(String agencyId, {String? reason}) =>
      _repository.suspend(agencyId, reason: reason);
}
