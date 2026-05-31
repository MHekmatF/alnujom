// Phase 19 follow-up (D-3) — LoadMyVerificationRequest use case.
//
// Loads the latest verification request for an agency so the verify page can
// surface the rejection reason to the owner when the agency is rejected.
// Zero Supabase imports (Constitution IX).
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/agency_verification_request.dart';
import '../repositories/agency_repository.dart';

@injectable
class LoadMyVerificationRequest {
  const LoadMyVerificationRequest(this._repository);

  final AgencyRepository _repository;

  Future<Result<AgencyVerificationRequest?>> call(String agencyId) =>
      _repository.loadMyVerificationRequest(agencyId);
}
