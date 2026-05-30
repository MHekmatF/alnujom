// Phase 19 (spec/019-agencies) — RemoveAgencyMember use case.
//
// Calls remove_agency_member(agency_id, user_id). Agency-admin only;
// the owner cannot be removed.
// Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/agency_repository.dart';

@injectable
class RemoveAgencyMember {
  const RemoveAgencyMember(this._repository);

  final AgencyRepository _repository;

  /// Returns [FailureResult] on:
  ///   - permission_denied (42501)
  ///   - cannot_remove_owner (42501)
  Future<Result<void>> call({
    required String agencyId,
    required String userId,
  }) =>
      _repository.removeMember(agencyId: agencyId, userId: userId);
}
