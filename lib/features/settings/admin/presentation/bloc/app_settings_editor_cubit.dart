// Phase 23 (spec/023-app-settings) — T014
// AppSettingsEditorCubit: drives the admin typed-settings editor.
// Load via LoadAllSettings (domain), edit-in-place, per-type validation,
// save via UpdateSetting.  Mirrors AdsAdminCubit structure.
// Constitution IX: zero supabase_flutter imports.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../domain/entities/app_setting.dart';
import '../../../domain/entities/app_setting_key.dart';
import '../../../domain/usecases/load_all_settings.dart';
import '../../../domain/usecases/update_setting.dart';

// ─── States ──────────────────────────────────────────────────────────────────

sealed class AppSettingsEditorState extends Equatable {
  const AppSettingsEditorState();

  @override
  List<Object?> get props => const [];
}

/// Initial / loading state — waiting for the first LoadAllSettings call to
/// complete.
class AppSettingsEditorLoading extends AppSettingsEditorState {
  const AppSettingsEditorLoading();
}

/// Settings loaded and ready to display / edit.
class AppSettingsEditorLoaded extends AppSettingsEditorState {
  const AppSettingsEditorLoaded({
    required this.settings,
    this.savingKey,
    this.lastSavedKey,
    this.saveFailure,
  });

  /// The flat list of all setting rows from the backend.
  final List<AppSetting> settings;

  /// The key currently being persisted via UpdateSetting (null when idle).
  final AppSettingKey? savingKey;

  /// The key of the most-recently-saved row (cleared on next load/save).
  final AppSettingKey? lastSavedKey;

  /// Non-null when the last save operation failed.
  final Failure? saveFailure;

  bool get isSaving => savingKey != null;

  /// Returns the current [AppSetting] for [key], or null if not yet loaded.
  AppSetting? settingFor(AppSettingKey key) {
    for (final s in settings) {
      if (s.key == key.key) return s;
    }
    return null;
  }

  AppSettingsEditorLoaded copyWith({
    List<AppSetting>? settings,
    AppSettingKey? savingKey,
    bool clearSavingKey = false,
    AppSettingKey? lastSavedKey,
    bool clearLastSavedKey = false,
    Failure? saveFailure,
    bool clearSaveFailure = false,
  }) {
    return AppSettingsEditorLoaded(
      settings: settings ?? this.settings,
      savingKey: clearSavingKey ? null : (savingKey ?? this.savingKey),
      lastSavedKey:
          clearLastSavedKey ? null : (lastSavedKey ?? this.lastSavedKey),
      saveFailure:
          clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
    );
  }

  @override
  List<Object?> get props => [settings, savingKey, lastSavedKey, saveFailure];
}

/// A domain or network failure loading the settings list.
class AppSettingsEditorError extends AppSettingsEditorState {
  const AppSettingsEditorError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

// ─── Cubit ───────────────────────────────────────────────────────────────────

@injectable
class AppSettingsEditorCubit extends Cubit<AppSettingsEditorState> {
  AppSettingsEditorCubit(
    this._loadAllSettings,
    this._updateSetting,
  ) : super(const AppSettingsEditorLoading());

  final LoadAllSettings _loadAllSettings;
  final UpdateSetting _updateSetting;

  // ── Load ─────────────────────────────────────────────────────────────────

  /// Loads all settings rows on entry or after a pull-to-refresh.
  Future<void> load() async {
    emit(const AppSettingsEditorLoading());
    final result = await _loadAllSettings();
    switch (result) {
      case Success<List<AppSetting>>(:final value):
        emit(AppSettingsEditorLoaded(settings: value));
      case FailureResult<List<AppSetting>>(:final failure):
        emit(AppSettingsEditorError(failure));
    }
  }

  // ── Save (per-key) ───────────────────────────────────────────────────────

  /// Validates [value] for [key] and, when valid, persists it via UpdateSetting.
  ///
  /// Returns null on success, or an error message string on validation failure
  /// (the editor widget displays this inline instead of calling save).
  Future<String?> save(AppSettingKey key, Object value) async {
    final validationError = _validate(key, value);
    if (validationError != null) return validationError;

    final current = state;
    if (current is! AppSettingsEditorLoaded) return null;

    emit(current.copyWith(
      savingKey: key,
      clearSaveFailure: true,
      clearLastSavedKey: true,
    ));

    final result = await _updateSetting(key, value);
    switch (result) {
      case Success<AppSetting>(:final value):
        // Update just the changed row in the local list, then clear saving state.
        final updated = [
          for (final s in current.settings)
            if (s.key == value.key) value else s,
        ];
        emit(
          AppSettingsEditorLoaded(
            settings: updated,
            lastSavedKey: key,
          ),
        );
        return null;
      case FailureResult<AppSetting>(:final failure):
        emit(
          current.copyWith(clearSavingKey: true, saveFailure: failure),
        );
        return failure.message;
    }
  }

  // ── Validation ───────────────────────────────────────────────────────────

  /// Returns an error message string when [value] fails structural validation
  /// for [key], or null when the value is acceptable.
  ///
  /// The RPC does authoritative validation on the backend; this is a
  /// client-side fast-fail for obvious structural errors only.
  String? _validate(AppSettingKey key, Object value) {
    switch (key) {
      case AppSettingKey.defaultLanguage:
        if (value is! String || !{'ar', 'en'}.contains(value)) {
          return 'Language must be "ar" or "en"';
        }
      case AppSettingKey.defaultCurrency:
        if (value is! String || (value).trim().isEmpty) {
          return 'Currency code is required';
        }
      case AppSettingKey.defaultPublisherNameVisibility:
        if (value is! String || (value).trim().isEmpty) {
          return 'Publisher name visibility is required';
        }
      case AppSettingKey.defaultLocationVisibility:
        if (value is! String || (value).trim().isEmpty) {
          return 'Location visibility is required';
        }
      case AppSettingKey.maintenanceMode:
        if (value is! Map) {
          return 'Maintenance mode must be a map';
        }
        if (value['on'] is! bool) {
          return 'Maintenance mode "on" must be a boolean';
        }
      case AppSettingKey.supportContact:
        if (value is! Map) {
          return 'Support contact must be a map';
        }
        // At least one channel should be set (warn but do not block)
        final phone = value['phone'];
        final whatsapp = value['whatsapp'];
        final email = value['email'];
        final hasAny =
            (phone is String && phone.isNotEmpty) ||
            (whatsapp is String && whatsapp.isNotEmpty) ||
            (email is String && email.isNotEmpty);
        if (!hasAny) {
          return 'At least one support channel is required';
        }
      case AppSettingKey.termsUrl:
      case AppSettingKey.privacyUrl:
        // Nullable — empty string is accepted (treated as "unset").
        if (value is! String) {
          return 'URL must be a text value';
        }
        if (value.isNotEmpty &&
            !value.startsWith('http://') &&
            !value.startsWith('https://')) {
          return 'URL must start with http:// or https://';
        }
    }
    return null;
  }
}
