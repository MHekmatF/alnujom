import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/role_assignment_summary.dart';
import '../../domain/entities/role_with_counts.dart';
import '../../domain/entities/user_search_result.dart';
import '../../domain/usecases/assign_role_to_user.dart';
import '../../domain/usecases/list_roles.dart';
import '../../domain/usecases/load_user_assignments.dart';
import '../../domain/usecases/revoke_role_from_user.dart';
import '../../domain/usecases/search_users.dart';

sealed class AssignRoleEvent extends Equatable {
  const AssignRoleEvent();

  @override
  List<Object?> get props => [];
}

final class UpdateUserQuery extends AssignRoleEvent {
  const UpdateUserQuery(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class SelectUser extends AssignRoleEvent {
  const SelectUser(this.user);

  final UserSearchResult user;

  @override
  List<Object?> get props => [user];
}

final class GrantRole extends AssignRoleEvent {
  const GrantRole({required this.targetUserId, required this.targetRoleId});

  final String targetUserId;
  final String targetRoleId;

  @override
  List<Object?> get props => [targetUserId, targetRoleId];
}

final class GrantSuperAdminRole extends AssignRoleEvent {
  const GrantSuperAdminRole({
    required this.targetUserId,
    required this.targetRoleId,
    required this.confirmationToken,
  });

  final String targetUserId;
  final String targetRoleId;
  final String confirmationToken;

  @override
  List<Object?> get props => [targetUserId, targetRoleId, confirmationToken];
}

final class RevokeRole extends AssignRoleEvent {
  const RevokeRole({required this.targetUserId, required this.targetRoleId});

  final String targetUserId;
  final String targetRoleId;

  @override
  List<Object?> get props => [targetUserId, targetRoleId];
}

final class ClearAssignRoleAction extends AssignRoleEvent {
  const ClearAssignRoleAction();
}

sealed class AssignRoleState extends Equatable {
  const AssignRoleState({this.action});

  final AssignRoleAction? action;

  @override
  List<Object?> get props => [action];
}

final class AssignRoleInitial extends AssignRoleState {
  const AssignRoleInitial() : super();
}

final class AssignRoleSearching extends AssignRoleState {
  const AssignRoleSearching(this.query) : super();

  final String query;

  @override
  List<Object?> get props => [query, action];
}

final class AssignRoleReady extends AssignRoleState {
  const AssignRoleReady({
    required this.query,
    required this.results,
    required this.roles,
    this.selectedUser,
    this.currentRoles = const <RoleAssignmentSummary>[],
    this.loadingDrawer = false,
    super.action,
  });

  final String query;
  final List<UserSearchResult> results;
  final List<RoleWithCounts> roles;
  final UserSearchResult? selectedUser;
  final List<RoleAssignmentSummary> currentRoles;
  final bool loadingDrawer;

  AssignRoleReady copyWith({
    String? query,
    List<UserSearchResult>? results,
    List<RoleWithCounts>? roles,
    UserSearchResult? selectedUser,
    List<RoleAssignmentSummary>? currentRoles,
    bool? loadingDrawer,
    AssignRoleAction? action,
    bool clearAction = false,
  }) {
    return AssignRoleReady(
      query: query ?? this.query,
      results: results ?? this.results,
      roles: roles ?? this.roles,
      selectedUser: selectedUser ?? this.selectedUser,
      currentRoles: currentRoles ?? this.currentRoles,
      loadingDrawer: loadingDrawer ?? this.loadingDrawer,
      action: clearAction ? null : action ?? this.action,
    );
  }

  @override
  List<Object?> get props => [
    query,
    results,
    roles,
    selectedUser,
    currentRoles,
    loadingDrawer,
    action,
  ];
}

sealed class AssignRoleAction extends Equatable {
  const AssignRoleAction();

  @override
  List<Object?> get props => [];
}

final class NeedSuperAdminConfirmation extends AssignRoleAction {
  const NeedSuperAdminConfirmation(this.targetUser, this.targetRoleId);

  final UserSearchResult targetUser;
  final String targetRoleId;

  @override
  List<Object?> get props => [targetUser, targetRoleId];
}

final class AssignRoleSucceeded extends AssignRoleAction {
  const AssignRoleSucceeded();
}

final class RevokeRoleSucceeded extends AssignRoleAction {
  const RevokeRoleSucceeded();
}

final class AssignRoleFailed extends AssignRoleAction {
  const AssignRoleFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

@injectable
class AssignRoleBloc extends Bloc<AssignRoleEvent, AssignRoleState> {
  AssignRoleBloc(
    this._searchUsers,
    this._loadUserAssignments,
    this._assignRoleToUser,
    this._revokeRoleFromUser,
    this._listRoles,
  ) : super(const AssignRoleInitial()) {
    on<UpdateUserQuery>(_search);
    on<SelectUser>(_selectUser);
    on<GrantRole>(_grantRole);
    on<GrantSuperAdminRole>(_grantSuperAdminRole);
    on<RevokeRole>(_revokeRole);
    on<ClearAssignRoleAction>(_clearAction);
  }

  final SearchUsers _searchUsers;
  final LoadUserAssignments _loadUserAssignments;
  final AssignRoleToUser _assignRoleToUser;
  final RevokeRoleFromUser _revokeRoleFromUser;
  final ListRoles _listRoles;

  Future<void> _search(
    UpdateUserQuery event,
    Emitter<AssignRoleState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(const AssignRoleReady(query: '', results: [], roles: []));
      return;
    }
    emit(AssignRoleSearching(query));
    try {
      final results = await _searchUsers(query);
      final roles = await _listRoles();
      emit(AssignRoleReady(query: query, results: results, roles: roles));
    } on Failure catch (failure) {
      emit(
        AssignRoleReady(
          query: query,
          results: const [],
          roles: const [],
          action: AssignRoleFailed(failure),
        ),
      );
    }
  }

  Future<void> _selectUser(
    SelectUser event,
    Emitter<AssignRoleState> emit,
  ) async {
    final ready = _readyState();
    if (ready == null) return;
    emit(ready.copyWith(selectedUser: event.user, loadingDrawer: true));
    try {
      final assignments = await _loadUserAssignments(event.user.userId);
      emit(
        ready.copyWith(
          selectedUser: event.user.copyWith(currentRoles: assignments),
          currentRoles: assignments,
          loadingDrawer: false,
          clearAction: true,
        ),
      );
    } on Failure catch (failure) {
      emit(
        ready.copyWith(loadingDrawer: false, action: AssignRoleFailed(failure)),
      );
    }
  }

  Future<void> _grantRole(
    GrantRole event,
    Emitter<AssignRoleState> emit,
  ) async {
    final ready = _readyState();
    final targetUser = ready?.selectedUser;
    if (ready == null || targetUser == null) return;
    final role = ready.roles
        .where((role) => role.roleId == event.targetRoleId)
        .firstOrNull;
    if (role?.roleKey == 'super_admin') {
      emit(
        ready.copyWith(
          action: NeedSuperAdminConfirmation(targetUser, event.targetRoleId),
        ),
      );
      return;
    }
    await _assignAndReload(event.targetUserId, event.targetRoleId, null, emit);
  }

  Future<void> _grantSuperAdminRole(
    GrantSuperAdminRole event,
    Emitter<AssignRoleState> emit,
  ) async {
    await _assignAndReload(
      event.targetUserId,
      event.targetRoleId,
      event.confirmationToken,
      emit,
    );
  }

  Future<void> _revokeRole(
    RevokeRole event,
    Emitter<AssignRoleState> emit,
  ) async {
    final ready = _readyState();
    final targetUser = ready?.selectedUser;
    if (ready == null || targetUser == null) return;
    try {
      await _revokeRoleFromUser(
        targetUserId: event.targetUserId,
        targetRoleId: event.targetRoleId,
      );
      final assignments = await _loadUserAssignments(targetUser.userId);
      emit(
        ready.copyWith(
          selectedUser: targetUser.copyWith(currentRoles: assignments),
          currentRoles: assignments,
          action: const RevokeRoleSucceeded(),
        ),
      );
    } on Failure catch (failure) {
      emit(ready.copyWith(action: AssignRoleFailed(failure)));
    }
  }

  void _clearAction(
    ClearAssignRoleAction event,
    Emitter<AssignRoleState> emit,
  ) {
    final ready = _readyState();
    if (ready != null) emit(ready.copyWith(clearAction: true));
  }

  Future<void> _assignAndReload(
    String targetUserId,
    String targetRoleId,
    String? confirmationToken,
    Emitter<AssignRoleState> emit,
  ) async {
    final ready = _readyState();
    final targetUser = ready?.selectedUser;
    if (ready == null || targetUser == null) return;
    try {
      await _assignRoleToUser(
        targetUserId: targetUserId,
        targetRoleId: targetRoleId,
        confirmationToken: confirmationToken,
      );
      final assignments = await _loadUserAssignments(targetUser.userId);
      emit(
        ready.copyWith(
          selectedUser: targetUser.copyWith(currentRoles: assignments),
          currentRoles: assignments,
          action: const AssignRoleSucceeded(),
        ),
      );
    } on Failure catch (failure) {
      emit(ready.copyWith(action: AssignRoleFailed(failure)));
    }
  }

  AssignRoleReady? _readyState() {
    final current = state;
    return current is AssignRoleReady ? current : null;
  }
}
