// Phase 19 (spec/019-agencies) — LoadAgencyAnalytics use case.
//
// Returns bounded analytics counters: active member count + listing-by-status
// counts. Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/agency_repository.dart';

export '../repositories/agency_repository.dart' show AgencyAnalytics;

@injectable
class LoadAgencyAnalytics {
  const LoadAgencyAnalytics(this._repository);

  final AgencyRepository _repository;

  Future<Result<AgencyAnalytics>> call(String agencyId) =>
      _repository.loadAnalytics(agencyId);
}
