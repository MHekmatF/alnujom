import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/update_availability.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../datasources/package_info_version_source.dart';
import '../datasources/supabase_manifest_datasource.dart';

/// Concrete implementation of [AppUpdateRepository].
///
/// **Fail-silent invariant (FR-010 / R-210)**: every error path — network
/// failure, malformed JSON, unparseable semver, any unexpected throw — returns
/// [Success<CheckFailed>].  The app NEVER shows an error to the user and NEVER
/// crashes because the manifest is unavailable.
///
/// Comparison logic (R-210):
/// - [UpdateAvailable] when `latest > installed` (semver-first, build tiebreaker).
/// - [UpToDate] otherwise (same or older manifest version).
@LazySingleton(as: AppUpdateRepository)
class AppUpdateRepositoryImpl implements AppUpdateRepository {
  AppUpdateRepositoryImpl(
    this._manifestDatasource,
    this._versionSource,
    this._logger,
  );

  static const _tag = 'AppUpdateRepository';

  final SupabaseManifestDatasource _manifestDatasource;
  final PackageInfoVersionSource _versionSource;
  final AppLogger _logger;

  @override
  Future<Result<UpdateAvailability>> checkForUpdate() async {
    try {
      final installed = await _versionSource.getInstalledVersion();
      final dto = await _manifestDatasource.fetchManifest();

      if (dto == null) {
        _logger.warning('Version manifest missing latest_version.', tag: _tag);
        return const Success(CheckFailed());
      }

      final manifest = dto.toDomain();
      if (manifest == null) {
        _logger.warning(
          'Version manifest latest_version could not be parsed.',
          tag: _tag,
        );
        return const Success(CheckFailed());
      }

      final cmp = manifest.latest.compareTo(installed);
      if (cmp > 0) {
        // Plan A31 — below the floor, the prompt is not dismissible. Only
        // meaningful when there is a newer build to move to, hence inside
        // the cmp > 0 branch: a floor above the latest is a manifest mistake
        // and must not lock anyone out.
        final floor = manifest.minSupported;
        final required = floor != null && installed.compareTo(floor) < 0;
        return Success(UpdateAvailable(manifest, required: required));
      }
      return const Success(UpToDate());
    } on Object catch (e, st) {
      // Catch-all: unreachable Storage, StorageException, FormatException, etc.
      // — all are silent no-ops per FR-010.
      _logger.warning(
        'Update check failed (silent).',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      return const Success(CheckFailed());
    }
  }
}
