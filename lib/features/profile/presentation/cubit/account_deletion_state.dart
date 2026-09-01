import 'package:equatable/equatable.dart';

import '../../domain/repositories/profile_repository.dart';

enum AccountDeletionStatus {
  /// The confirmation screen is showing; nothing has been sent yet.
  idle,

  /// The RPC is in flight — the confirm action must stay disabled.
  submitting,

  /// The account is gone. The caller signs the user out and leaves.
  success,

  /// The RPC failed; the account is untouched and the user is still signed in.
  failure,
}

/// State for [AccountDeletionCubit] — a deliberately tiny, single-purpose
/// state so the irreversible action never shares a state object with the
/// editable profile form.
class AccountDeletionState extends Equatable {
  const AccountDeletionState({
    this.status = AccountDeletionStatus.idle,
    this.failure,
  });

  final AccountDeletionStatus status;
  final ProfileFailure? failure;

  bool get isSubmitting => status == AccountDeletionStatus.submitting;

  @override
  List<Object?> get props => [status, failure];
}
