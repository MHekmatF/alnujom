import 'app_version.dart';
import 'localized_text.dart';

/// The operator-published version manifest (data-model §1 / R-209).
///
/// Hosted on Supabase Storage (public-read); the client reads it on cold start
/// and compares [latest] to the installed version to decide whether to prompt.
///
/// [minSupported] is parsed but **not enforced** in v1 (forward-stated).
class VersionManifest {
  const VersionManifest({
    required this.latest,
    this.minSupported,
    this.telegramUrl,
    this.websiteUrl,
    this.releaseNotes,
  });

  /// The latest released version.  Used for the semver+build comparison.
  final AppVersion latest;

  /// The minimum supported version.  Parsed but ignored in v1 — reserved for
  /// a future force-update gate (forward-stated — data-model §1).
  final AppVersion? minSupported;

  /// Primary download channel (Telegram).  Preferred target of the Update
  /// button in the prompt (R-211 — `telegram_url ?? website_url`).
  final String? telegramUrl;

  /// Secondary/web download URL.  Used as the Update target only when
  /// [telegramUrl] is null.
  final String? websiteUrl;

  /// Optional localized short release note shown in the prompt.
  final LocalizedText? releaseNotes;

  /// The effective download URL: [telegramUrl] first, then [websiteUrl].
  String? get downloadUrl => telegramUrl ?? websiteUrl;

  @override
  String toString() =>
      'VersionManifest(latest: $latest, telegram: $telegramUrl)';
}
