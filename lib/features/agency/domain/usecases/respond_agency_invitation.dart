// Phase 19 (spec/019-agencies) — RespondAgencyInvitation use case.
//
// Calls respond_agency_invitation(agency_id, accept) for the invitee only
// (bound to auth.uid()). Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/agency_repository.dart';

@injectable
class RespondAgencyInvitation {
  const RespondAgencyInvitation(this._repository);

  final AgencyRepository _repository;

  /// Returns [FailureResult] on no_pending_invitation (P0002).
  Future<Result<void>> call({
    required String agencyId,
    required bool accept,
  }) =>
      _repository.respondInvitation(agencyId: agencyId, accept: accept);
}
