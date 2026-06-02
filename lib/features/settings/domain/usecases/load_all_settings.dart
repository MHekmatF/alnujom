import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/app_setting.dart';
import '../repositories/app_settings_repository.dart';

/// Load all settings rows (public + sensitive, subject to RLS).
///
/// Consumed by FA's `AppSettingsEditorCubit`.  Returns the flat list of
/// [AppSetting] rows so the editor can render per-key controls with
/// descriptions.
@injectable
class LoadAllSettings {
  const LoadAllSettings(this._repository);

  final AppSettingsRepository _repository;

  Future<Result<List<AppSetting>>> call() => _repository.loadAllSettings();
}
