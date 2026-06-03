import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../../domain/entities/account_approval_request.dart';
import '../../domain/usecases/approve_account.dart';
import '../../domain/usecases/load_pending_queue.dart';
import '../../domain/usecases/reject_account.dart';
import 'account_approvals_state.dart';

@injectable
class AccountApprovalsCubit extends Cubit<AccountApprovalsState> {
  AccountApprovalsCubit(
    this._loadPendingQueue,
    this._approveAccount,
    this._rejectAccount,
  ) : super(const AccountApprovalsInitial());

  final LoadPendingQueue _loadPendingQueue;
  final ApproveAccount _approveAccount;
  final RejectAccount _rejectAccount;

  Future<void> loadPending() async {
    emit(const AccountApprovalsLoading());
    final result = await _loadPendingQueue();
    if (isClosed) return;
    switch (result) {
      case Success<List<AccountApprovalRequest>>(:final value):
        emit(AccountApprovalsLoaded(value));
      case FailureResult<List<AccountApprovalRequest>>(:final failure):
        emit(AccountApprovalsError(failure));
    }
  }

  Future<void> approve(String userId) async {
    final current = _currentRequests();
    if (current == null) return;
    emit(AccountApprovalsMutating(current));
    final result = await _approveAccount(userId: userId);
    if (isClosed) return;
    if (result is FailureResult<void>) {
      emit(AccountApprovalsError(result.failure));
      return;
    }
    await loadPending();
  }

  Future<void> reject(String userId, String reason) async {
    final current = _currentRequests();
    if (current == null) return;
    emit(AccountApprovalsMutating(current));
    final result = await _rejectAccount(userId: userId, reason: reason);
    if (isClosed) return;
    if (result is FailureResult<void>) {
      emit(AccountApprovalsError(result.failure));
      return;
    }
    await loadPending();
  }

  List<AccountApprovalRequest>? _currentRequests() {
    return switch (state) {
      AccountApprovalsLoaded(:final requests) => requests,
      AccountApprovalsMutating(:final requests) => requests,
      _ => null,
    };
  }
}
