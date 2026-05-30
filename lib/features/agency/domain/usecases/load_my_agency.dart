// Phase 19 (spec/019-agencies) — LoadMyAgency use case.
//
// Reads the current user's own agency via public.v_agencies (SECURITY DEFINER).
// Returns null when the user has no agency. Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/agency.dart';
import '../repositories/agency_repository.dart';

@injectable
class LoadMyAgency {
  const LoadMyAgency(this._repository);

  final AgencyRepository _repository;

  /// Returns [Success] with the [Agency] if found, or `null` if the user has
  /// no agency yet.
  Future<Result<Agency?>> call() => _repository.loadMyAgency();
}
