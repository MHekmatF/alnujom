import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/private_contact_methods.dart';
import '../repositories/profile_repository.dart';

@injectable
class UpdatePii {
  const UpdatePii(this._repository);

  final ProfileRepository _repository;

  Future<Result<void>> saveLegalName(String value) =>
      _repository.updateLegalName(value.trim());

  Future<Result<void>> saveNationalId(String value) =>
      _repository.updateNationalId(value.trim());

  Future<Result<void>> saveContactMethods(PrivateContactMethods methods) =>
      _repository.updatePrivateContactMethods(methods);
}
