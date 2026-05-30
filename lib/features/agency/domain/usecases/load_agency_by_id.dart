// Phase 19 (spec/019-agencies) — LoadAgencyById use case.
//
// Reads a single agency by id via public.v_agencies (SECURITY DEFINER).
// Returns null when the agency is not visible to the caller. Zero Supabase
// imports (Constitution IX). Powers the public /agency/:id page (T055) and the
// listing-details verified badge (T061).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/agency.dart';
import '../repositories/agency_repository.dart';

@injectable
class LoadAgencyById {
  const LoadAgencyById(this._repository);

  final AgencyRepository _repository;

  Future<Result<Agency?>> call(String agencyId) =>
      _repository.loadAgencyById(agencyId);
}
