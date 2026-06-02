part of 'app_settings_cubit.dart';

/// Lifecycle status of the [AppSettingsCubit] fetch.
enum AppSettingsStatus {
  /// Initial state before the first fetch completes (carries safe defaults).
  initial,

  /// A fetch is in flight (still carries the last-known / safe-default snapshot).
  loading,

  /// A fetch succeeded; [AppSettingsState.settings] is the live snapshot.
  loaded,

  /// A fetch failed; [AppSettingsState.settings] is [AppSettings.safeDefaults]
  /// (fail-open — maintenance OFF, app runs — FR-014).
  failedOpen,
}

/// Immutable state for [AppSettingsCubit].
///
/// [settings] is ALWAYS non-null so consumers (the maintenance gate, about page,
/// seeding) never need a null check. Before the first successful fetch — and on
/// any fetch failure — it holds [AppSettings.safeDefaults].
class AppSettingsState extends Equatable {
  const AppSettingsState({required this.status, required this.settings});

  /// The pre-fetch state: safe defaults, maintenance OFF.
  const AppSettingsState.initial()
    : status = AppSettingsStatus.initial,
      settings = const AppSettings.safeDefaults();

  final AppSettingsStatus status;
  final AppSettings settings;

  AppSettingsState copyWith({
    AppSettingsStatus? status,
    AppSettings? settings,
  }) {
    return AppSettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
    );
  }

  @override
  List<Object?> get props => [status, settings];
}
