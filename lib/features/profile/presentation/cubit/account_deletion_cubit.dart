import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/request_account_deletion.dart';
import 'account_deletion_state.dart';

/// Drives the one irreversible action in the profile feature.
///
/// Kept separate from [ProfileCubit] on purpose: account deletion must never be
/// reachable from a state transition of the editable profile form, and its
/// in-flight guard has to be unambiguous.
@injectable
class AccountDeletionCubit extends Cubit<AccountDeletionState> {
  AccountDeletionCubit(this._requestAccountDeletion)
    : super(const AccountDeletionState());

  final RequestAccountDeletion _requestAccountDeletion;

  /// Sends the deletion request. Re-entrant calls while one is in flight are
  /// ignored so a double tap cannot fire two RPCs.
  Future<void> submit() async {
    if (state.isSubmitting) return;
    emit(const AccountDeletionState(status: AccountDeletionStatus.submitting));

    final result = await _requestAccountDeletion();
    if (isClosed) return;

    if (result is Success<void>) {
      emit(const AccountDeletionState(status: AccountDeletionStatus.success));
      return;
    }

    final failure = (result as FailureResult<void>).failure;
    emit(
      AccountDeletionState(
        status: AccountDeletionStatus.failure,
        failure: failure is ProfileFailure
            ? failure
            : UnknownProfileError(failure.message),
      ),
    );
  }
}
