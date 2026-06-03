import '../../../../core/errors/result.dart';
import '../entities/update_availability.dart';

/// Repository interface for the in-app update check (data-model §3 / FR-008).
///
/// Implementations MUST:
/// - Never throw — all errors are mapped to [CheckFailed] (FR-010).
/// - Keep `supabase_flutter` and `package_info_plus` imports strictly in
///   `data/` (Principle IX — domain is platform-SDK-free).
abstract interface class AppUpdateRepository {
  /// Compare the installed version to the Supabase-Storage manifest.
  ///
  /// Returns:
  /// - [Success<UpdateAvailable>]  — a newer version exists.
  /// - [Success<UpToDate>]         — installed version is current.
  /// - [Success<CheckFailed>]      — manifest unreachable / malformed /
  ///                                  `latest_version` absent (FR-010).
  ///
  /// The [Result] wrapper is provided for uniformity with the rest of the
  /// codebase; in practice this method always returns [Success] (the inner
  /// [CheckFailed] variant already encodes the error path).
  Future<Result<UpdateAvailability>> checkForUpdate();
}
