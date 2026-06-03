import '../../domain/entities/app_version.dart';
import '../../domain/entities/localized_text.dart';
import '../../domain/entities/version_manifest.dart';

/// Data-transfer object for the Supabase-Storage version manifest JSON.
///
/// Schema (data-model §1 / R-209 / docs/release/version-manifest.example.json):
/// ```jsonc
/// {
///   "latest_version":      "1.0.0",    // REQUIRED — semver
///   "latest_build":        1,           // OPTIONAL — build tiebreaker
///   "min_supported_version": null,      // OPTIONAL — forward-stated, v1 ignored
///   "download": {
///     "telegram_url": "https://t.me/…",
///     "website_url":  null
///   },
///   "release_notes": { "ar": null, "en": null }
/// }
/// ```
///
/// Tolerant decoding (FR-010):
/// - Any missing or null optional field is silently treated as absent.
/// - A missing/unparseable `latest_version` causes [fromJson] to return `null`,
///   which the repository maps to [CheckFailed].
/// - Unknown extra fields are ignored.
class VersionManifestDto {
  const VersionManifestDto._({
    required this.latestVersion,
    required this.latestBuild,
    this.minSupportedVersion,
    this.telegramUrl,
    this.websiteUrl,
    this.releaseNotesAr,
    this.releaseNotesEn,
  });

  final String latestVersion;
  final int latestBuild;
  final String? minSupportedVersion;
  final String? telegramUrl;
  final String? websiteUrl;
  final String? releaseNotesAr;
  final String? releaseNotesEn;

  /// Decode a manifest JSON map.
  ///
  /// Returns `null` if [json] is missing `latest_version` or the value is
  /// not a non-empty string — the repository treats null as [CheckFailed].
  static VersionManifestDto? fromJson(Map<String, dynamic> json) {
    final rawVersion = json['latest_version'];
    if (rawVersion is! String || rawVersion.isEmpty) return null;

    final download = json['download'];
    final String? telegramUrl = download is Map
        ? _asStringOrNull(download['telegram_url'])
        : null;
    final String? websiteUrl = download is Map
        ? _asStringOrNull(download['website_url'])
        : null;

    final notes = json['release_notes'];
    final String? arNote = notes is Map
        ? _asStringOrNull(notes['ar'])
        : null;
    final String? enNote = notes is Map
        ? _asStringOrNull(notes['en'])
        : null;

    return VersionManifestDto._(
      latestVersion: rawVersion,
      latestBuild: json['latest_build'] is int ? json['latest_build'] as int : 0,
      minSupportedVersion: _asStringOrNull(json['min_supported_version']),
      telegramUrl: telegramUrl,
      websiteUrl: websiteUrl,
      releaseNotesAr: arNote,
      releaseNotesEn: enNote,
    );
  }

  /// Convert to the domain [VersionManifest].
  ///
  /// Returns `null` if [latestVersion] cannot be parsed as semver — the
  /// repository maps this to [CheckFailed].
  VersionManifest? toDomain() {
    final AppVersion latest;
    try {
      latest = AppVersion.parse(latestVersion, build: latestBuild);
    } on FormatException {
      return null;
    }

    AppVersion? minSupported;
    if (minSupportedVersion != null) {
      try {
        minSupported = AppVersion.parse(minSupportedVersion!);
      } on FormatException {
        // forward-stated field; tolerate parse failure silently
      }
    }

    final LocalizedText? releaseNotes =
        (releaseNotesAr != null || releaseNotesEn != null)
            ? LocalizedText(ar: releaseNotesAr, en: releaseNotesEn)
            : null;

    return VersionManifest(
      latest: latest,
      minSupported: minSupported,
      telegramUrl: telegramUrl,
      websiteUrl: websiteUrl,
      releaseNotes: releaseNotes,
    );
  }

  static String? _asStringOrNull(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }
}
