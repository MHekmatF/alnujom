import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/usecases/load_public_settings.dart';

part 'app_settings_state.dart';

/// Phase 23 (FC / T020) — session-scoped singleton holding the current public
/// [AppSettings] snapshot used by the maintenance gate, the about/support
/// surface, and registration/new-listing seeding.
///
/// Registered as a [lazySingleton] so the global `redirect` in `app_router.dart`
/// can read the cached snapshot synchronously via `getIt<AppSettingsCubit>()`
/// (the redirect must never do a network fetch — that is this cubit's job).
///
/// **Fail-open invariant (FR-014 / R-201)**: when [load] fails (offline, server
/// error), the cubit serves [AppSettings.safeDefaults] — maintenance OFF, the
/// app runs normally, and nothing crashes. A fetch error NEVER shows the
/// maintenance screen.
@lazySingleton
class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit(this._loadPublicSettings)
    : super(const AppSettingsState.initial());

  final LoadPublicSettings _loadPublicSettings;

  /// The current effective settings snapshot. Always non-null: starts at
  /// [AppSettings.safeDefaults] and is replaced once a fetch succeeds, or
  /// kept at safe defaults if every fetch has failed (fail-open).
  AppSettings get current => state.settings;

  /// Whether the global maintenance gate should be active right now.
  ///
  /// Derived solely from the loaded snapshot's maintenance flag. On the
  /// fail-open path this is `false` (safe defaults have maintenance OFF), so a
  /// failed fetch can never lock users out.
  bool get maintenanceActive => state.settings.maintenance.isOn;

  /// Fetches the public settings snapshot.
  ///
  /// Called at app-start, on foreground-resume (T025), and by the maintenance
  /// screen's retry button (T021). On success, emits the fresh snapshot. On
  /// failure, emits [AppSettings.safeDefaults] (fail-open) — never throws.
  Future<void> load() async {
    emit(state.copyWith(status: AppSettingsStatus.loading));
    final result = await _loadPublicSettings();
    switch (result) {
      case Success(:final value):
        emit(
          AppSettingsState(status: AppSettingsStatus.loaded, settings: value),
        );
      case FailureResult():
        // Fail-open / fail-safe (FR-014): serve safe defaults, maintenance OFF.
        emit(
          const AppSettingsState(
            status: AppSettingsStatus.failedOpen,
            settings: AppSettings.safeDefaults(),
          ),
        );
    }
  }
}
