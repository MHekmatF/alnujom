import '../../../../core/errors/result.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../entities/password_reset_outcome.dart';
import '../repositories/auth_repository.dart';

/// Domain use case: requests a password reset and reports what the server could
/// do — mail sent, phone-only account, or no such account.
///
/// [FailureResult] only on transport failure.
class RequestPasswordReset {
  const RequestPasswordReset(this._repository);

  final AuthRepository _repository;

  Future<Result<PasswordResetOutcome>> call(PhoneNumber phone) =>
      _repository.requestPasswordReset(phone: phone);
}
