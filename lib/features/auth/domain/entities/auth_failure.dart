import '../../../../core/errors/failure.dart';

/// Auth-feature-specific failure types (Phase 5 FR-011 / FR-017).
///
/// All extend the project's [Failure] base so they slot into [Result] uniformly.
/// The reset-password path emits no specific failure type — the Edge Function is
/// account-enumeration-resistant by contract; only transport-level failures
/// surface as [NetworkFailure].
sealed class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.cause, super.stackTrace});
}

/// Login failure: phone unknown OR password wrong (uniform message per FR-017).
final class InvalidPhoneOrPassword extends AuthFailure {
  const InvalidPhoneOrPassword({super.cause, super.stackTrace})
    : super('invalid_phone_or_password');
}

/// Registration failure: phone already in use.
final class AccountAlreadyExists extends AuthFailure {
  const AccountAlreadyExists({super.cause, super.stackTrace})
    : super('account_already_exists');
}

/// Registration failure: password length < 8 (defensive — UI validator catches first).
final class PasswordTooShort extends AuthFailure {
  const PasswordTooShort({super.cause, super.stackTrace})
    : super('password_too_short');
}

/// Catch-all auth-side error (e.g., unmapped Supabase error).
final class UnknownAuthError extends AuthFailure {
  const UnknownAuthError(super.message, {super.cause, super.stackTrace});
}
