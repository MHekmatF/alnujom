part of 'app_update_cubit.dart';

/// Lifecycle status of the [AppUpdateCubit] check.
enum AppUpdateStatus {
  /// Initial state before any check has been issued.
  initial,

  /// A version-manifest check is in flight.
  checking,

  /// The check completed: installed version is up to date.
  upToDate,

  /// The check completed: a newer version is available.  [AppUpdateState.manifest]
  /// carries the [VersionManifest] for the prompt dialog.
  updateAvailable,

  /// The check failed (network, malformed manifest, etc.).
  /// MUST be treated as a silent no-op — no error UI (FR-010).
  checkFailed,
}

/// Immutable state for [AppUpdateCubit].
class AppUpdateState extends Equatable {
  const AppUpdateState({required this.status, this.manifest});

  const AppUpdateState.initial()
      : status = AppUpdateStatus.initial,
        manifest = null;

  final AppUpdateStatus status;

  /// Non-null only when [status] == [AppUpdateStatus.updateAvailable].
  final VersionManifest? manifest;

  @override
  List<Object?> get props => [status, manifest];
}
