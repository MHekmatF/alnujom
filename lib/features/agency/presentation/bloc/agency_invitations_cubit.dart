// lib/features/agency/presentation/bloc/agency_invitations_cubit.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T048).
// Pending invitations across all agencies + accept/decline.
// LoadMyAgencyInvitations enriches each pending membership with its agency
// name (via LoadAgencyById) so the card can show "Invitation from {name}".
// RespondAgencyInvitation accepts/declines. Zero Supabase imports.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/agency.dart';
import '../../domain/entities/agency_member.dart';
import '../../domain/usecases/load_agency_by_id.dart';
import '../../domain/usecases/load_my_agency_invitations.dart';
import '../../domain/usecases/respond_agency_invitation.dart';

/// One pending invitation enriched with the inviting agency's display name.
class AgencyInvitation {
  const AgencyInvitation({required this.membership, required this.agencyName});

  final AgencyMember membership;

  /// Inviting agency name; falls back to the agency id when the name is not
  /// resolvable (e.g. the agency is not approved and the view hides it).
  final String agencyName;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

sealed class AgencyInvitationsState {
  const AgencyInvitationsState();
}

final class AgencyInvitationsLoading extends AgencyInvitationsState {
  const AgencyInvitationsLoading();
}

final class AgencyInvitationsLoaded extends AgencyInvitationsState {
  const AgencyInvitationsLoaded(this.invitations, {this.responding = false});

  final List<AgencyInvitation> invitations;
  final bool responding;
}

final class AgencyInvitationsError extends AgencyInvitationsState {
  const AgencyInvitationsError();
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

@injectable
class AgencyInvitationsCubit extends Cubit<AgencyInvitationsState> {
  AgencyInvitationsCubit(
    this._loadInvitations,
    this._loadAgencyById,
    this._respond,
  ) : super(const AgencyInvitationsLoading());

  final LoadMyAgencyInvitations _loadInvitations;
  final LoadAgencyById _loadAgencyById;
  final RespondAgencyInvitation _respond;

  Future<void> load() async {
    emit(const AgencyInvitationsLoading());
    final result = await _loadInvitations();
    if (isClosed) return;
    switch (result) {
      case Success<List<AgencyMember>>(:final value):
        final enriched = <AgencyInvitation>[];
        for (final m in value) {
          final agencyResult = await _loadAgencyById(m.agencyId);
          if (isClosed) return;
          final Agency? agency =
              agencyResult is Success<Agency?> ? agencyResult.value : null;
          enriched.add(
            AgencyInvitation(
              membership: m,
              agencyName: agency?.name ?? m.agencyId,
            ),
          );
        }
        emit(AgencyInvitationsLoaded(enriched));
      case FailureResult<List<AgencyMember>>():
        emit(const AgencyInvitationsError());
    }
  }

  Future<void> respond({required String agencyId, required bool accept}) async {
    final current = state;
    if (current is AgencyInvitationsLoaded) {
      emit(AgencyInvitationsLoaded(current.invitations, responding: true));
    }
    await _respond(agencyId: agencyId, accept: accept);
    // Reload regardless of outcome so the list reflects the server state.
    await load();
  }
}
