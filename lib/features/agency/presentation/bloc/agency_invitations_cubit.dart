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
  const AgencyInvitation({required this.membership, this.agencyName});

  final AgencyMember membership;

  /// Inviting agency name, or `null` when it is not resolvable — `v_agencies`
  /// hides a not-yet-approved agency from a PENDING invitee (`is_agency_member`
  /// requires `status = 'active'`), which is the common case for a fresh
  /// invitation. The UI substitutes a localized placeholder; it must never show
  /// the raw UUID, which reads as a broken screen (B-4 follow-up).
  final String? agencyName;
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
            AgencyInvitation(membership: m, agencyName: agency?.name),
          );
        }
        emit(AgencyInvitationsLoaded(enriched));
      case FailureResult<List<AgencyMember>>():
        emit(const AgencyInvitationsError());
    }
  }

  /// Accepts or declines the invitation for [agencyId], then reloads.
  ///
  /// Returns the RPC's [Result] so the caller can react to the outcome: the
  /// result used to be discarded, which made a failed Accept (e.g. the P0002
  /// `no_pending_invitation`) look like a silent no-op, and left a successful
  /// Accept sitting on an empty list instead of moving on to the agency.
  Future<Result<void>> respond({
    required String agencyId,
    required bool accept,
  }) async {
    final current = state;
    if (current is AgencyInvitationsLoaded) {
      emit(AgencyInvitationsLoaded(current.invitations, responding: true));
    }
    final result = await _respond(agencyId: agencyId, accept: accept);
    if (isClosed) return result;
    // Reload regardless of outcome so the list reflects the server state.
    await load();
    return result;
  }
}
