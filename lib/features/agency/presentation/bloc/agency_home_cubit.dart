// lib/features/agency/presentation/bloc/agency_home_cubit.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T045).
// Resolves the agency-home state: none (no agency) / owner / member, by
// combining LoadMyAgency (owner-only) with LoadMyActiveAgencies (owner OR
// invited member). Mirrors the reports cubits' @injectable + sealed-state
// pattern. Zero Supabase imports (Constitution IX).
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/agency.dart';
import '../../domain/entities/agency_member.dart';
import '../../domain/usecases/create_agency.dart';
import '../../domain/usecases/load_agency_by_id.dart';
import '../../domain/usecases/load_my_active_agencies.dart';
import '../../domain/usecases/load_my_agency.dart';
import '../../domain/usecases/load_my_agency_invitations.dart';
import '../../domain/usecases/respond_agency_invitation.dart';
import 'agency_invitations_cubit.dart' show AgencyInvitation;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

sealed class AgencyHomeState {
  const AgencyHomeState();
}

final class AgencyHomeLoading extends AgencyHomeState {
  const AgencyHomeLoading();
}

/// The user owns no agency (and is a member of none) — the create form shows.
final class AgencyHomeNone extends AgencyHomeState {
  const AgencyHomeNone();
}

/// The user owns an agency (the management surface shows, full controls).
final class AgencyHomeOwner extends AgencyHomeState {
  const AgencyHomeOwner(this.agency);

  final Agency agency;
}

/// The user is an active member of an agency they do NOT own (management
/// surface in member mode — no owner-only actions).
final class AgencyHomeMember extends AgencyHomeState {
  const AgencyHomeMember(this.agency);

  final Agency agency;
}

/// The user owns no agency and is an active member of none, but has one or more
/// PENDING invitations. The hub surfaces them with Accept/Decline (alongside the
/// create form). Without this state an invitee only ever saw the create form and
/// could never reach the Accept action — it lived solely on the Members page,
/// which is unreachable until you are already a member (the B-4 finding).
final class AgencyHomeInvited extends AgencyHomeState {
  const AgencyHomeInvited(this.invitations, {this.responding = false});

  final List<AgencyInvitation> invitations;
  final bool responding;
}

final class AgencyHomeError extends AgencyHomeState {
  const AgencyHomeError();
}

/// Transient state while the create-agency RPC is in flight (the create form
/// disables its submit button and shows a spinner).
final class AgencyHomeCreating extends AgencyHomeState {
  const AgencyHomeCreating();
}

/// The create-agency RPC failed; [messageKey] is the failure code (e.g.
/// `not_a_publisher`, `already_owns_agency`, `invalid_name`) the form maps to
/// a localized message.
final class AgencyHomeCreateFailure extends AgencyHomeState {
  const AgencyHomeCreateFailure(this.messageKey);

  final String messageKey;
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

@injectable
class AgencyHomeCubit extends Cubit<AgencyHomeState> {
  AgencyHomeCubit(
    this._loadMyAgency,
    this._loadMyActiveAgencies,
    this._createAgency,
    this._loadInvitations,
    this._loadAgencyById,
    this._respondInvitation,
  ) : super(const AgencyHomeLoading());

  final LoadMyAgency _loadMyAgency;
  final LoadMyActiveAgencies _loadMyActiveAgencies;
  final CreateAgency _createAgency;
  final LoadMyAgencyInvitations _loadInvitations;
  final LoadAgencyById _loadAgencyById;
  final RespondAgencyInvitation _respondInvitation;

  Future<void> load() async {
    emit(const AgencyHomeLoading());

    final ownedResult = await _loadMyAgency();
    if (isClosed) return;
    if (ownedResult is Success<Agency?> && ownedResult.value != null) {
      emit(AgencyHomeOwner(ownedResult.value!));
      return;
    }
    if (ownedResult is FailureResult<Agency?>) {
      emit(const AgencyHomeError());
      return;
    }

    // No owned agency — check for an ACTIVE membership in someone else's agency.
    final memberResult = await _loadMyActiveAgencies();
    if (isClosed) return;
    if (memberResult is Success<List<Agency>> && memberResult.value.isNotEmpty) {
      emit(AgencyHomeMember(memberResult.value.first));
      return;
    }
    if (memberResult is FailureResult<List<Agency>>) {
      emit(const AgencyHomeError());
      return;
    }

    // No owned agency, no active membership — surface any PENDING invitations so
    // the invitee can Accept/Decline from the hub (the create form alone left
    // them with no path to Accept). Invitation read failure is non-fatal: fall
    // back to the plain create form.
    final invResult = await _loadInvitations();
    if (isClosed) return;
    if (invResult is Success<List<AgencyMember>> && invResult.value.isNotEmpty) {
      final enriched = <AgencyInvitation>[];
      for (final m in invResult.value) {
        final agencyResult = await _loadAgencyById(m.agencyId);
        if (isClosed) return;
        final agency =
            agencyResult is Success<Agency?> ? agencyResult.value : null;
        enriched.add(
          AgencyInvitation(
            membership: m,
            agencyName: agency?.name ?? m.agencyId,
          ),
        );
      }
      emit(AgencyHomeInvited(enriched));
      return;
    }

    emit(const AgencyHomeNone());
  }

  /// Accept or decline a pending invitation, then reload so the hub re-resolves
  /// (accept → AgencyHomeMember; decline → remaining invitations / None).
  Future<void> respondInvitation({
    required String agencyId,
    required bool accept,
  }) async {
    final current = state;
    if (current is AgencyHomeInvited) {
      emit(AgencyHomeInvited(current.invitations, responding: true));
    }
    await _respondInvitation(agencyId: agencyId, accept: accept);
    await load();
  }

  /// Calls `create_agency`; on success reloads the home state so the create
  /// form is replaced by the owner management surface.
  Future<void> create({
    required String name,
    String? description,
    String? phone,
    String? whatsapp,
    String? address,
  }) async {
    emit(const AgencyHomeCreating());
    final result = await _createAgency(
      name: name,
      description: description,
      phone: phone,
      whatsapp: whatsapp,
      address: address,
    );
    // The create RPC is awaited above; if the form was disposed mid-flight,
    // bail before emitting (load() on the success branch is itself guarded).
    if (isClosed) return;
    switch (result) {
      case Success<String>():
        await load();
      case FailureResult<String>(:final failure):
        emit(AgencyHomeCreateFailure(_failureKey(failure)));
    }
  }

  String _failureKey(Failure failure) {
    if (failure is ValidationFailure) return failure.code;
    if (failure is PermissionDeniedFailure) return 'permission_denied';
    return 'unknown';
  }
}
