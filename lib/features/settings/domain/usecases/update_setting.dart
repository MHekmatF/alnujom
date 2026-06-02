import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/app_setting.dart';
import '../entities/app_setting_key.dart';
import '../repositories/app_settings_repository.dart';

/// Persist a setting change via the `set_app_setting` SECURITY DEFINER RPC.
///
/// Consumed by FA's `AppSettingsEditorCubit.save(key, value)`.
///
/// [key]   — one of the 8 catalog keys ([AppSettingKey]).
/// [value] — decoded Dart value (String, bool, Map, etc.); the repository
///   impl encodes it as JSONB before passing to the datasource.
@injectable
class UpdateSetting {
  const UpdateSetting(this._repository);

  final AppSettingsRepository _repository;

  Future<Result<AppSetting>> call(AppSettingKey key, Object value) =>
      _repository.updateSetting(key, value);
}
