// Phase 19 (spec/019-agencies) — LoadMyAgencyInvitations use case.
//
// Loads pending invitations for the current user across all agencies via
// public.agency_members (status='pending'). Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/agency_member.dart';
import '../repositories/agency_repository.dart';

@injectable
class LoadMyAgencyInvitations {
  const LoadMyAgencyInvitations(this._repository);

  final AgencyRepository _repository;

  Future<Result<List<AgencyMember>>> call() =>
      _repository.loadMyInvitations();
}
