// Phase 19 (spec/019-agencies) — T040
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../../../../agency/domain/entities/agency_status.dart';
import '../entities/agency_verification_item.dart';
import '../repositories/agencies_admin_repository.dart';

@injectable
class LoadAgencyVerificationQueue {
  const LoadAgencyVerificationQueue(this._repository);

  final AgenciesAdminRepository _repository;

  Future<Result<List<AgencyVerificationItem>>> call({
    AgencyStatus? status,
    String? cursor,
    int limit = 30,
  }) =>
      _repository.loadQueue(
        status: status,
        cursor: cursor,
        limit: limit,
      );
}
