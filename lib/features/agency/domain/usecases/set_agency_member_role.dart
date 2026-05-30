// Phase 19 (spec/019-agencies) — SetAgencyMemberRole use case.
//
// Calls set_agency_member_role(agency_id, user_id, role). Agency-admin only;
// the owner is protected from role changes.
// Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/agency_repository.dart';

@injectable
class SetAgencyMemberRole {
  const SetAgencyMemberRole(this._repository);

  final AgencyRepository _repository;

  /// Returns [FailureResult] on:
  ///   - permission_denied (42501)
  ///   - invalid_role (22023)
  ///   - cannot_modify_owner (42501)
  Future<Result<void>> call({
    required String agencyId,
    required String userId,
    required String role,
  }) =>
      _repository.setMemberRole(agencyId: agencyId, userId: userId, role: role);
}
