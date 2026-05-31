// Phase 19 (spec/019-agencies) — CreateAgency use case.
//
// Calls create_agency(name, description?, phone?, whatsapp?, address?)
// SECURITY DEFINER RPC via the repository. Authenticated + approved publisher;
// one agency per owner. Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/agency_repository.dart';

@injectable
class CreateAgency {
  const CreateAgency(this._repository);

  final AgencyRepository _repository;

  /// Returns the new agency UUID string on success.
  Future<Result<String>> call({
    required String name,
    String? description,
    String? phone,
    String? whatsapp,
    String? address,
  }) =>
      _repository.createAgency(
        name: name,
        description: description,
        phone: phone,
        whatsapp: whatsapp,
        address: address,
      );
}
