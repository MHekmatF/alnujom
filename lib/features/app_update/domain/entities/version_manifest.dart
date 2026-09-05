import 'app_version.dart';
import 'localized_text.dart';

/// The operator-published version manifest (data-model §1 / R-209).
///
/// Hosted on Supabase Storage (public-read); the client reads it on cold start
/// and compares [latest] to the installed version to decide whether to prompt.
///
/// [minSupported] is the forced-update floor since plan A31 (2026-09-05):
/// an installed build below it gets a prompt it cannot dismiss.
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

  /// The minimum supported version. Below it the update prompt has no
  /// "later" and no back (plan A31). Null means no floor.
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
