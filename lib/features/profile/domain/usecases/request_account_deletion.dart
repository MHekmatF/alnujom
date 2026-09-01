import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/profile_repository.dart';

/// Permanently deletes the signed-in user's own account.
///
/// Deliberately parameterless: the server RPC always acts on the authenticated
/// caller, so there is no user id to get wrong. Constitution IX — no Supabase
/// types cross this boundary.
@injectable
class RequestAccountDeletion {
  const RequestAccountDeletion(this._repository);

  final ProfileRepository _repository;

  Future<Result<void>> call() => _repository.requestAccountDeletion();
}
