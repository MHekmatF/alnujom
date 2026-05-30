// Phase 19 (spec/019-agencies) — LoadAgencyMembers use case.
//
// Loads the active roster for an agency. Accessible to active members and
// agencies.view holders. Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/agency_member.dart';
import '../repositories/agency_repository.dart';

@injectable
class LoadAgencyMembers {
  const LoadAgencyMembers(this._repository);

  final AgencyRepository _repository;

  Future<Result<List<AgencyMember>>> call(String agencyId) =>
      _repository.loadMembers(agencyId);
}
