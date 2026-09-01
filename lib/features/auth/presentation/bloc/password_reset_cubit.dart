// Reset-request state for the "forgot password" screen.
//
// Scoped per page instance (@injectable, NOT a singleton) — the same idiom as
// SetNewPasswordCubit. This deliberately does NOT live on AuthBloc: asking for
// a reset link is not a change to the app's auth state, and the old handler had
// to emit Authenticating and then restore the previous state just to borrow a
// spinner, which made the global router hold for an unrelated request.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../../domain/entities/password_reset_outcome.dart';
import '../../domain/usecases/request_password_reset.dart';

enum PasswordResetStatus { idle, submitting, done, failure }

final class PasswordResetState {
  const PasswordResetState({
    this.status = PasswordResetStatus.idle,
    this.outcome,
  });

  final PasswordResetStatus status;

  /// What the server could do — only set once [status] is
  /// [PasswordResetStatus.done].
  final PasswordResetOutcome? outcome;

  bool get isSubmitting => status == PasswordResetStatus.submitting;
  bool get isDone => status == PasswordResetStatus.done;
  bool get isFailure => status == PasswordResetStatus.failure;
}

@injectable
class PasswordResetCubit extends Cubit<PasswordResetState> {
  PasswordResetCubit(this._requestPasswordReset)
    : super(const PasswordResetState());

  final RequestPasswordReset _requestPasswordReset;

  /// Returns the screen to the form so the user can correct the number.
  void reset() {
    if (state.status == PasswordResetStatus.idle) return;
    emit(const PasswordResetState());
  }

  Future<void> submit(PhoneNumber phone) async {
    if (state.isSubmitting) return;
    emit(const PasswordResetState(status: PasswordResetStatus.submitting));
    final result = await _requestPasswordReset(phone);
    if (result is Success<PasswordResetOutcome>) {
      emit(
        PasswordResetState(
          status: PasswordResetStatus.done,
          outcome: result.value,
        ),
      );
    } else {
      emit(const PasswordResetState(status: PasswordResetStatus.failure));
    }
  }
}
