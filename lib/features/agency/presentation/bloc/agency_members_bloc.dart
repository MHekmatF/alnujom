// lib/features/agency/presentation/bloc/agency_members_bloc.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T046).
// Roster load + invite/set-role/remove member via the membership use cases.
// Events: Opened / InviteRequested / RoleChangeRequested / RemoveRequested.
// Mirrors the reports BLoC @injectable + sealed-event pattern. Zero Supabase
// imports (Constitution IX).
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/agency_member.dart';
import '../../domain/usecases/invite_agency_member.dart';
import '../../domain/usecases/load_agency_members.dart';
import '../../domain/usecases/remove_agency_member.dart';
import '../../domain/usecases/set_agency_member_role.dart';

part 'agency_members_state.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

sealed class AgencyMembersEvent {
  const AgencyMembersEvent();
}

final class AgencyMembersOpened extends AgencyMembersEvent {
  const AgencyMembersOpened(this.agencyId);
  final String agencyId;
}

final class AgencyMembersInviteRequested extends AgencyMembersEvent {
  const AgencyMembersInviteRequested({
    required this.agencyId,
    required this.phone,
    required this.role,
  });
  final String agencyId;
  final String phone;
  final String role;
}

final class AgencyMembersRoleChangeRequested extends AgencyMembersEvent {
  const AgencyMembersRoleChangeRequested({
    required this.agencyId,
    required this.userId,
    required this.role,
  });
  final String agencyId;
  final String userId;
  final String role;
}

final class AgencyMembersRemoveRequested extends AgencyMembersEvent {
  const AgencyMembersRemoveRequested({
    required this.agencyId,
    required this.userId,
  });
  final String agencyId;
  final String userId;
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------

@injectable
class AgencyMembersBloc extends Bloc<AgencyMembersEvent, AgencyMembersState> {
  AgencyMembersBloc(
    this._loadMembers,
    this._inviteMember,
    this._setMemberRole,
    this._removeMember,
  ) : super(const AgencyMembersLoading()) {
    on<AgencyMembersOpened>(_onOpened);
    on<AgencyMembersInviteRequested>(_onInvite);
    on<AgencyMembersRoleChangeRequested>(_onRoleChange);
    on<AgencyMembersRemoveRequested>(_onRemove);
  }

  final LoadAgencyMembers _loadMembers;
  final InviteAgencyMember _inviteMember;
  final SetAgencyMemberRole _setMemberRole;
  final RemoveAgencyMember _removeMember;

  Future<void> _onOpened(
    AgencyMembersOpened event,
    Emitter<AgencyMembersState> emit,
  ) async {
    await _reload(event.agencyId, emit);
  }

  Future<void> _onInvite(
    AgencyMembersInviteRequested event,
    Emitter<AgencyMembersState> emit,
  ) async {
    _markActionInProgress(emit);
    final result = await _inviteMember(
      agencyId: event.agencyId,
      phone: event.phone,
      role: event.role,
    );
    await _afterAction(event.agencyId, result, emit);
  }

  Future<void> _onRoleChange(
    AgencyMembersRoleChangeRequested event,
    Emitter<AgencyMembersState> emit,
  ) async {
    _markActionInProgress(emit);
    final result = await _setMemberRole(
      agencyId: event.agencyId,
      userId: event.userId,
      role: event.role,
    );
    await _afterAction(event.agencyId, result, emit);
  }

  Future<void> _onRemove(
    AgencyMembersRemoveRequested event,
    Emitter<AgencyMembersState> emit,
  ) async {
    _markActionInProgress(emit);
    final result = await _removeMember(
      agencyId: event.agencyId,
      userId: event.userId,
    );
    await _afterAction(event.agencyId, result, emit);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _markActionInProgress(Emitter<AgencyMembersState> emit) {
    final current = state;
    if (current is AgencyMembersLoaded) {
      emit(current.copyWith(actionInProgress: true, clearError: true));
    }
  }

  Future<void> _afterAction(
    String agencyId,
    Result<Object?> result,
    Emitter<AgencyMembersState> emit,
  ) async {
    switch (result) {
      case Success():
        await _reload(agencyId, emit);
      case FailureResult(:final failure):
        final current = state;
        final code = failure is ValidationFailure
            ? failure.code
            : (failure is PermissionDeniedFailure
                ? 'permission_denied'
                : 'unknown');
        if (current is AgencyMembersLoaded) {
          emit(current.copyWith(actionInProgress: false, actionError: code));
        } else {
          emit(const AgencyMembersError());
        }
    }
  }

  Future<void> _reload(
    String agencyId,
    Emitter<AgencyMembersState> emit,
  ) async {
    final result = await _loadMembers(agencyId);
    switch (result) {
      case Success<List<AgencyMember>>(:final value):
        emit(AgencyMembersLoaded(members: value));
      case FailureResult<List<AgencyMember>>():
        emit(const AgencyMembersError());
    }
  }
}
