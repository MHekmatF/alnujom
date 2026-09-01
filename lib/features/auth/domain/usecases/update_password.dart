import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/auth_repository.dart';

/// Domain use case (spec 005 D-01): sets a new password for the session that a
/// password-recovery deep link established.
///
/// Returns [FailureResult] with an `UnknownAuthError('recovery_session_missing')`
/// when the link expired or was already consumed.
@injectable
class UpdatePassword {
  const UpdatePassword(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call(String newPassword) =>
      _repository.updatePassword(newPassword: newPassword);
}
