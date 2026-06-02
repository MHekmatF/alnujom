import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/app_setting.dart';
import '../../domain/entities/app_setting_key.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../datasources/supabase_app_settings_datasource.dart';
import '../dtos/app_setting_dto.dart';

@LazySingleton(as: AppSettingsRepository)
class AppSettingsRepositoryImpl implements AppSettingsRepository {
  AppSettingsRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'AppSettingsRepositoryImpl';

  final SupabaseAppSettingsDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<AppSettings>> loadPublicSettings() async {
    try {
      final dtos = await _datasource.fetchSettings();
      return Success(AppSettingDto.toAppSettings(dtos));
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapPostgrest(e, st));
    } on Object catch (e, st) {
      return FailureResult(_mapUnknown(e, st));
    }
  }

  @override
  Future<Result<List<AppSetting>>> loadAllSettings() async {
    try {
      final dtos = await _datasource.fetchSettings();
      return Success(dtos.map((dto) => dto.toDomain()).toList());
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapPostgrest(e, st));
    } on Object catch (e, st) {
      return FailureResult(_mapUnknown(e, st));
    }
  }

  @override
  Future<Result<AppSetting>> updateSetting(
    AppSettingKey key,
    Object value,
  ) async {
    try {
      final dto = await _datasource.updateSetting(key, value);
      return Success(dto.toDomain());
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapPostgrest(e, st));
    } on Object catch (e, st) {
      return FailureResult(_mapUnknown(e, st));
    }
  }

  SettingsFailure _mapPostgrest(PostgrestException e, StackTrace st) {
    _logger.warning(
      'Settings data error.',
      error: e,
      stackTrace: st,
      tag: _tag,
    );
    final code = e.code ?? '';
    final message = e.message;
    return switch (code) {
      '42501' => SettingsPermissionDeniedFailure(message),
      'P0002' => SettingsUnknownKeyFailure(message),
      _ => SettingsUnknownFailure(message),
    };
  }

  SettingsFailure _mapUnknown(Object e, StackTrace st) {
    _logger.warning(
      'Settings unexpected error.',
      error: e,
      stackTrace: st,
      tag: _tag,
    );
    return SettingsUnknownFailure(e.toString());
  }
}

// ---------------------------------------------------------------------------
// Typed failure hierarchy for the settings feature.
// ---------------------------------------------------------------------------

sealed class SettingsFailure extends Failure {
  const SettingsFailure(super.message, {super.cause, super.stackTrace});

  /// Stable identifier for UI mapping.
  String get code;
}

/// Caller lacks the `settings.manage` permission (RPC SQLSTATE 42501).
final class SettingsPermissionDeniedFailure extends SettingsFailure {
  const SettingsPermissionDeniedFailure(super.message);

  @override
  String get code => 'permission_denied';
}

/// The supplied key is not in the v1 catalog (RPC SQLSTATE P0002).
final class SettingsUnknownKeyFailure extends SettingsFailure {
  const SettingsUnknownKeyFailure(super.message);

  @override
  String get code => 'unknown_key';
}

/// Any other error (network, unexpected PostgREST response, etc.).
final class SettingsUnknownFailure extends SettingsFailure {
  const SettingsUnknownFailure(super.message);

  @override
  String get code => 'unknown';
}
