// Phase 19 (spec/019-agencies) — LoadMyActiveAgencies use case.
//
// Loads the agencies the current user is an `active` member of (owner or
// invited-and-accepted) via public.agency_members + public.v_agencies. Zero
// Supabase imports (Constitution IX). Powers the publish-under-agency selector
// (T053/T062).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/agency.dart';
import '../repositories/agency_repository.dart';

@injectable
class LoadMyActiveAgencies {
  const LoadMyActiveAgencies(this._repository);

  final AgencyRepository _repository;

  Future<Result<List<Agency>>> call() => _repository.loadMyActiveAgencies();
}
