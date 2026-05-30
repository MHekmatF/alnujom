// lib/features/agency/presentation/bloc/agency_members_state.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T046).
part of 'agency_members_bloc.dart';

sealed class AgencyMembersState {
  const AgencyMembersState();
}

final class AgencyMembersLoading extends AgencyMembersState {
  const AgencyMembersLoading();
}

final class AgencyMembersLoaded extends AgencyMembersState {
  const AgencyMembersLoaded({
    required this.members,
    this.actionInProgress = false,
    this.actionError,
  });

  final List<AgencyMember> members;

  /// True while an invite/role/remove RPC is in flight.
  final bool actionInProgress;

  /// Failure code of the last action (e.g. `user_not_found`,
  /// `already_member`, `cannot_remove_owner`); null when none.
  final String? actionError;

  AgencyMembersLoaded copyWith({
    List<AgencyMember>? members,
    bool? actionInProgress,
    String? actionError,
    bool clearError = false,
  }) {
    return AgencyMembersLoaded(
      members: members ?? this.members,
      actionInProgress: actionInProgress ?? this.actionInProgress,
      actionError: clearError ? null : (actionError ?? this.actionError),
    );
  }
}

final class AgencyMembersError extends AgencyMembersState {
  const AgencyMembersError();
}
