// Phase 19 (spec/019-agencies) — SubmitAgencyVerification use case.
//
// Uploads verification documents and calls submit_agency_verification RPC.
// Agency-admin only; one open request per agency.
// Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/agency_repository.dart';

@injectable
class SubmitAgencyVerification {
  const SubmitAgencyVerification(this._repository);

  final AgencyRepository _repository;

  /// Returns the new verification request UUID on success.
  Future<Result<String>> call({
    required String agencyId,
    required String idDocumentNumber,
    required String registrationNumber,
    List<String>? evidenceUrls,
  }) =>
      _repository.submitVerification(
        agencyId: agencyId,
        idDocumentNumber: idDocumentNumber,
        registrationNumber: registrationNumber,
        evidenceUrls: evidenceUrls,
      );
}
