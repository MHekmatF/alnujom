import '../../../../core/errors/result.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../repositories/auth_repository.dart';

/// Domain use case: requests a password-reset link via the Edge Function.
///
/// Always returns [Success(null)] on any parseable response (FR-017).
/// Only [FailureResult] on transport failure.
class RequestPasswordReset {
  const RequestPasswordReset(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call(PhoneNumber phone) =>
      _repository.requestPasswordReset(phone: phone);
}
