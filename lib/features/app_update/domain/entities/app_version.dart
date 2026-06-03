/// Parsed semantic version with an optional build number.
///
/// Comparison rule (R-210):
/// 1. Compare major, minor, patch in order — the first non-zero delta wins.
/// 2. When semver is equal, compare [build] (higher build = newer).
/// 3. Returns negative / zero / positive, mirroring [Comparable.compareTo].
class AppVersion {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
  });

  final int major;
  final int minor;
  final int patch;

  /// Optional build number; used as a tiebreaker when the semver triple
  /// is identical (R-210).  Defaults to 0 when absent from the manifest.
  final int build;

  /// Parse a semver string ("major.minor.patch") and an optional [build]
  /// number into an [AppVersion].
  ///
  /// Throws [FormatException] if [semver] is not a valid "X.Y.Z" string.
  factory AppVersion.parse(String semver, {int build = 0}) {
    final parts = semver.trim().split('.');
    if (parts.length != 3) {
      throw FormatException('Invalid semver: $semver');
    }
    return AppVersion(
      major: int.parse(parts[0]),
      minor: int.parse(parts[1]),
      patch: int.parse(parts[2]),
      build: build,
    );
  }

  /// Semver-first comparison; [build] is the tiebreaker.
  ///
  /// Returns a negative integer if [this] is older than [other], zero if they
  /// are equal, or a positive integer if [this] is newer.
  int compareTo(AppVersion other) {
    final majorDiff = major - other.major;
    if (majorDiff != 0) return majorDiff;

    final minorDiff = minor - other.minor;
    if (minorDiff != 0) return minorDiff;

    final patchDiff = patch - other.patch;
    if (patchDiff != 0) return patchDiff;

    return build - other.build;
  }

  @override
  String toString() => '$major.$minor.$patch+$build';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          build == other.build;

  @override
  int get hashCode =>
      major.hashCode ^ minor.hashCode ^ patch.hashCode ^ build.hashCode;
}
