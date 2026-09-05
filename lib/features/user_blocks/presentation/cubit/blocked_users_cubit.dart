// Plan A29 — the "blocked users" settings page: load the list, lift a block.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/blocked_user.dart';
import '../../domain/usecases/load_blocked_users.dart';
import '../../domain/usecases/unblock_user.dart';

enum BlockedUsersStatus { loading, loaded, error }

final class BlockedUsersState extends Equatable {
  const BlockedUsersState({
    required this.status,
    this.users = const [],
    this.unblockingId,
    this.unblockFailedToken = 0,
  });

  const BlockedUsersState.loading() : this(status: BlockedUsersStatus.loading);

  final BlockedUsersStatus status;
  final List<BlockedUser> users;

  /// The user whose unblock is in flight, so only that row shows a spinner.
  final String? unblockingId;

  /// Monotonic one-shot signal: bumps when an unblock fails, so the page can
  /// toast without keeping error state around.
  final int unblockFailedToken;

  BlockedUsersState copyWith({
    BlockedUsersStatus? status,
    List<BlockedUser>? users,
    String? unblockingId,
    bool clearUnblocking = false,
    int? unblockFailedToken,
  }) {
    return BlockedUsersState(
      status: status ?? this.status,
      users: users ?? this.users,
      unblockingId: clearUnblocking ? null : (unblockingId ?? this.unblockingId),
      unblockFailedToken: unblockFailedToken ?? this.unblockFailedToken,
    );
  }

  @override
  List<Object?> get props => [status, users, unblockingId, unblockFailedToken];
}

@injectable
class BlockedUsersCubit extends Cubit<BlockedUsersState> {
  BlockedUsersCubit(this._loadBlockedUsers, this._unblockUser)
    : super(const BlockedUsersState.loading());

  final LoadBlockedUsers _loadBlockedUsers;
  final UnblockUser _unblockUser;

  Future<void> load() async {
    emit(state.copyWith(status: BlockedUsersStatus.loading));
    final result = await _loadBlockedUsers();
    if (isClosed) return;
    switch (result) {
      case Success(value: final users):
        emit(state.copyWith(status: BlockedUsersStatus.loaded, users: users));
      case FailureResult():
        emit(state.copyWith(status: BlockedUsersStatus.error));
    }
  }

  Future<void> unblock(String userId) async {
    if (state.unblockingId != null) return;
    emit(state.copyWith(unblockingId: userId));
    final result = await _unblockUser(userId);
    if (isClosed) return;
    switch (result) {
      case Success():
        emit(
          state.copyWith(
            clearUnblocking: true,
            users: state.users.where((u) => u.userId != userId).toList(),
          ),
        );
      case FailureResult():
        emit(
          state.copyWith(
            clearUnblocking: true,
            unblockFailedToken: state.unblockFailedToken + 1,
          ),
        );
    }
  }
}
