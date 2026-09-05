import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/update_availability.dart';
import '../../domain/entities/version_manifest.dart';
import '../../domain/usecases/check_for_update.dart';

part 'app_update_state.dart';

/// Phase 24 UP — cubit that drives the cold-start update-availability check.
///
/// [check] is called **once on cold start** (not on every resume) from
/// `app.dart` (T018 / R-211).  On [UpdateAvailable], `app.dart` shows the
/// update-prompt dialog exactly once per session (session-once, no persisted
/// dismissed-version state — R-211).
///
/// All error paths resolve to [AppUpdateStatus.checkFailed] — no error UI,
/// no crash (FR-010 / fail-silent).
@lazySingleton
class AppUpdateCubit extends Cubit<AppUpdateState> {
  AppUpdateCubit(this._checkForUpdate) : super(const AppUpdateState.initial());

  final CheckForUpdate _checkForUpdate;

  /// Perform the version-manifest check and emit the result state.
  ///
  /// Idempotent per session: callers may guard with `state.status ==
  /// AppUpdateStatus.initial` to avoid redundant checks, but the cubit itself
  /// is correct to call multiple times (used only once from `app.dart`).
  Future<void> check() async {
    if (isClosed) return;
    emit(const AppUpdateState(status: AppUpdateStatus.checking));
    final result = await _checkForUpdate();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        final status = switch (value) {
          UpdateAvailable() => AppUpdateStatus.updateAvailable,
          UpToDate() => AppUpdateStatus.upToDate,
          CheckFailed() => AppUpdateStatus.checkFailed,
        };
        final VersionManifest? manifest =
            value is UpdateAvailable ? value.manifest : null;
        emit(
          AppUpdateState(
            status: status,
            manifest: manifest,
            updateRequired: value is UpdateAvailable && value.required,
          ),
        );
      case FailureResult():
        // Repository always returns Success — this branch is for safety only.
        emit(const AppUpdateState(status: AppUpdateStatus.checkFailed));
    }
  }
}
