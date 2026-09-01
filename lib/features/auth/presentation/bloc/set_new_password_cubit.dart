// lib/features/auth/presentation/bloc/set_new_password_cubit.dart
//
// Spec 005 D-01 — "set a new password" state for the reset-completion screen.
//
// Scoped per page instance (@injectable, NOT a singleton): the global auth
// state machine stays [AuthBloc]'s job, so no new AuthState variant is added
// here (the router's exhaustive switch in auth_redirect.dart depends on it).
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/auth_failure.dart';
import '../../domain/usecases/update_password.dart';

/// Why a password update failed, in UI terms.
enum SetNewPasswordError {
  /// The recovery link expired or was already consumed — no session to update.
  sessionMissing,

  /// The server rejected the password (too short / too weak).
  weakPassword,

  /// Transport or unmapped server error — offer a retry.
  unknown,
}

/// Lifecycle of the "choose a new password" submission.
enum SetNewPasswordStatus { idle, submitting, success, failure }

final class SetNewPasswordState {
  const SetNewPasswordState({
    this.status = SetNewPasswordStatus.idle,
    this.error,
  });

  final SetNewPasswordStatus status;
  final SetNewPasswordError? error;

  bool get isSubmitting => status == SetNewPasswordStatus.submitting;
  bool get isSuccess => status == SetNewPasswordStatus.success;
}

@injectable
class SetNewPasswordCubit extends Cubit<SetNewPasswordState> {
  SetNewPasswordCubit(this._updatePassword)
    : super(const SetNewPasswordState());

  final UpdatePassword _updatePassword;

  /// Clears a previous failure so the inline error disappears as the user
  /// edits the fields again.
  void clearError() {
    if (state.status != SetNewPasswordStatus.failure) return;
    emit(const SetNewPasswordState());
  }

  Future<void> submit(String newPassword) async {
    if (state.isSubmitting) return;
    emit(const SetNewPasswordState(status: SetNewPasswordStatus.submitting));

    final result = await _updatePassword(newPassword);
    if (isClosed) return;

    switch (result) {
      case Success<void>():
        emit(const SetNewPasswordState(status: SetNewPasswordStatus.success));
      case FailureResult<void>(:final failure):
        emit(
          SetNewPasswordState(
            status: SetNewPasswordStatus.failure,
            error: _mapFailure(failure),
          ),
        );
    }
  }

  SetNewPasswordError _mapFailure(Object failure) => switch (failure) {
    PasswordTooShort() => SetNewPasswordError.weakPassword,
    // The repository flags "no session" with this sentinel message — the
    // codebase's established idiom for carrying a reason on UnknownAuthError.
    UnknownAuthError(:final message)
        when message == 'recovery_session_missing' =>
      SetNewPasswordError.sessionMissing,
    _ => SetNewPasswordError.unknown,
  };
}
