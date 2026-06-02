import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/app_settings.dart';
import '../repositories/app_settings_repository.dart';

/// Load the public settings snapshot.
///
/// Consumed by:
/// - FC's `AppSettingsCubit.load()` on app-start and foreground-resume (R-201).
/// - FC's registration seeding path in `auth_repository_impl.dart` (R-203).
@injectable
class LoadPublicSettings {
  const LoadPublicSettings(this._repository);

  final AppSettingsRepository _repository;

  Future<Result<AppSettings>> call() => _repository.loadPublicSettings();
}
