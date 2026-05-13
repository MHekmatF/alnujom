import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../../shared/domain/entities/profile.dart';
import '../repositories/profile_repository.dart';

@injectable
class LoadProfile {
  const LoadProfile(this._repository);

  final ProfileRepository _repository;

  Future<Result<Profile>> call() => _repository.getCurrentProfile();
}
