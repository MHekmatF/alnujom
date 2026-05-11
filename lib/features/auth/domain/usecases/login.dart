import '../../../../core/errors/result.dart';
import '../../../../shared/domain/value_objects/phone_number.dart';
import '../entities/session.dart';
import '../repositories/auth_repository.dart';

/// Domain use case: calls [AuthRepository.login].
class Login {
  const Login(this._repository);

  final AuthRepository _repository;

  Future<Result<Session>> call({
    required PhoneNumber phone,
    required String password,
  }) => _repository.login(phone: phone, password: password);
}
