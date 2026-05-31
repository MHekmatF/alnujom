// Phase 19 (spec/019-agencies) — InviteAgencyMember use case.
//
// Calls invite_agency_member(agency_id, phone, role) SECURITY DEFINER RPC.
// Agency-admin only; resolves phone to an existing account.
// Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/agency_repository.dart';

@injectable
class InviteAgencyMember {
  const InviteAgencyMember(this._repository);

  final AgencyRepository _repository;

  /// Returns the invited user's UUID on success.
  /// Returns [FailureResult] on:
  ///   - permission_denied (42501)
  ///   - invalid_role (22023)
  ///   - user_not_found (23503)
  Future<Result<String>> call({
    required String agencyId,
    required String phone,
    String role = 'agent',
  }) =>
      _repository.inviteMember(agencyId: agencyId, phone: phone, role: role);
}
