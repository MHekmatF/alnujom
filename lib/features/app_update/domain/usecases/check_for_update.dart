import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/update_availability.dart';
import '../repositories/app_update_repository.dart';

/// Use case: compare the installed app version to the Supabase-Storage
/// version manifest and return whether an update is available.
///
/// Thin orchestrator — all comparison logic lives in the repository/datasource.
/// The cubit calls this once on cold start (T015 / R-211).
@injectable
class CheckForUpdate {
  const CheckForUpdate(this._repository);

  final AppUpdateRepository _repository;

  Future<Result<UpdateAvailability>> call() => _repository.checkForUpdate();
}
