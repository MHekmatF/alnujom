import '../repositories/auth_repository.dart';

/// Domain use case: calls [AuthRepository.logout].
class Logout {
  const Logout(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.logout();
}
