// Phase 19 (spec/019-agencies) — UpdateAgencyProfile use case.
//
// Updates the agency profile fields (agency-admin only).
// Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/agency_repository.dart';

@injectable
class UpdateAgencyProfile {
  const UpdateAgencyProfile(this._repository);

  final AgencyRepository _repository;

  Future<Result<void>> call({
    required String agencyId,
    String? name,
    String? description,
    String? phone,
    String? whatsapp,
    String? address,
    String? logoPath,
    String? coverPath,
  }) =>
      _repository.updateProfile(
        agencyId: agencyId,
        name: name,
        description: description,
        phone: phone,
        whatsapp: whatsapp,
        address: address,
        logoPath: logoPath,
        coverPath: coverPath,
      );
}
