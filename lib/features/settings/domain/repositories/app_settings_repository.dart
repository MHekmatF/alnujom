import '../../../../core/errors/result.dart';
import '../entities/app_setting.dart';
import '../entities/app_setting_key.dart';
import '../entities/app_settings.dart';

/// Repository interface for app-wide admin-tunable settings.
///
/// All methods return `Result<T>` — callers switch on `Success` /
/// `FailureResult` and never throw.  The concrete implementation is
/// `AppSettingsRepositoryImpl` in `data/repositories/`.
///
/// RLS enforcement summary (data-model §1.1 / R-197):
/// - [loadPublicSettings]: returns only `is_public = true` rows for
///   non-`settings.manage` callers; returns all rows for `settings.manage`
///   holders.  The public snapshot is the FC-facing fetch.
/// - [loadAllSettings]: intended for the FA admin editor.  In practice Supabase
///   RLS still applies (sensitive keys require `settings.manage`), so calling
///   this as a regular user returns the same public subset as [loadPublicSettings].
/// - [updateSetting]: proxied through the `set_app_setting` SECURITY DEFINER
///   RPC; the RPC re-checks `settings.manage` server-side (R-199 / FR-004).
abstract class AppSettingsRepository {
  /// Fetch the public settings snapshot (RLS: `is_public = true` for non-admins).
  ///
  /// Used by FC's `AppSettingsCubit` on load + resume, and for registration
  /// seeding.  Returns [AppSettings] with typed getters.
  Future<Result<AppSettings>> loadPublicSettings();

  /// Fetch all settings rows (RLS: `is_public OR settings.manage`).
  ///
  /// Used by FA's `AppSettingsEditorCubit`.  Returns the raw list so the
  /// editor can display each key individually, including description metadata.
  Future<Result<List<AppSetting>>> loadAllSettings();

  /// Persist a setting change via the `set_app_setting` SECURITY DEFINER RPC.
  ///
  /// [key] — the catalog key to update.
  /// [value] — the new decoded value (String, bool, Map, etc.); the datasource
  ///   encodes it as JSONB before sending.
  ///
  /// Errors:
  /// - `42501` → `SettingsPermissionDeniedFailure` (caller lacks `settings.manage`).
  /// - `P0002` → `SettingsUnknownKeyFailure` (key not in v1 catalog — should not
  ///   happen when using the [AppSettingKey] enum).
  Future<Result<AppSetting>> updateSetting(AppSettingKey key, Object value);
}
