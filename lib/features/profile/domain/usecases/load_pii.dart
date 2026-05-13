import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/profile_repository.dart';

@injectable
class LoadPii {
  const LoadPii(this._repository);

  final ProfileRepository _repository;

  Future<Result<PiiBundle>> call() => _repository.loadPii();
}
