import 'version_manifest.dart';

/// Sealed result of an update-availability check (data-model §3 / R-210).
///
/// - [UpdateAvailable]  — a newer version exists; the manifest is attached for
///                        the dialog to show release notes + the download URL.
/// - [UpToDate]         — the installed version is current; no prompt.
/// - [CheckFailed]      — the manifest was unreachable/malformed; no prompt,
///                        no error UI — a silent no-op (FR-010).
sealed class UpdateAvailability {
  const UpdateAvailability();
}

/// A newer version is available.
final class UpdateAvailable extends UpdateAvailability {
  const UpdateAvailable(this.manifest, {this.required = false});

  final VersionManifest manifest;

  /// Plan A31 — the installed build is below the manifest's
  /// `min_supported_version`: the prompt cannot be dismissed.
  final bool required;
}

/// The installed version is up to date.
final class UpToDate extends UpdateAvailability {
  const UpToDate();
}

/// The check could not be completed (network error, malformed manifest, etc.).
/// The caller MUST treat this as a silent no-op — no error toast, no crash.
final class CheckFailed extends UpdateAvailability {
  const CheckFailed();
}
