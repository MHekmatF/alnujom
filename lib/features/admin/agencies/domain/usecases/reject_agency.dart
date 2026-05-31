// Phase 19 (spec/019-agencies) — T040
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../repositories/agencies_admin_repository.dart';

@injectable
class RejectAgency {
  const RejectAgency(this._repository);

  final AgenciesAdminRepository _repository;

  Future<Result<void>> call(
    String agencyId, {
    required String preset,
    String? detail,
  }) =>
      _repository.reject(agencyId, preset: preset, detail: detail);
}
