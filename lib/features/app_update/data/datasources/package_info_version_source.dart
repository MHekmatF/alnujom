import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/entities/app_version.dart';

/// Retrieves the currently-installed app version via `package_info_plus`.
///
/// This is the SOLE importer of `package_info_plus` for the `app_update`
/// feature — `domain/` has zero platform-SDK imports (Principle IX / T019).
///
/// The version string comes from `pubspec.yaml` (`version: 1.0.0+1`):
/// - [PackageInfo.version]     → the semver part ("1.0.0").
/// - [PackageInfo.buildNumber] → the build number ("1").
@injectable
class PackageInfoVersionSource {
  const PackageInfoVersionSource();

  /// Returns the installed [AppVersion], or throws [FormatException] if
  /// `PackageInfo.version` is not a valid semver string.
  Future<AppVersion> getInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    return AppVersion.parse(info.version, build: build);
  }
}
