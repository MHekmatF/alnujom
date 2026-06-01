// Phase 21 (spec/021-ads-banners) — AdStatus enum.
//
// DERIVED status — never stored in the database (R-171).
// Computed from `isActive`, `archivedAt`, `startAt`, `endAt` vs `DateTime.now()`.
//
// Priority order (highest → lowest, first match wins):
//   archived  → archivedAt != null
//   inactive  → !isActive (and not archived)
//   scheduled → now() < startAt (not yet started)
//   expired   → endAt != null && now() >= endAt
//   active    → otherwise eligible
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

/// Derived display/filter status of an [Ad].
///
/// Use [Ad.status] (computed getter) rather than constructing this directly.
enum AdStatus {
  active,
  scheduled,
  expired,
  inactive,
  archived;

  /// Compute the status from stored flags and schedule window.
  ///
  /// [now] defaults to [DateTime.now] and can be injected for tests.
  static AdStatus compute({
    required bool isActive,
    required DateTime? archivedAt,
    required DateTime? startAt,
    required DateTime? endAt,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    if (archivedAt != null) return AdStatus.archived;
    if (!isActive) return AdStatus.inactive;
    if (startAt != null && t.isBefore(startAt)) return AdStatus.scheduled;
    if (endAt != null && !t.isBefore(endAt)) return AdStatus.expired;
    return AdStatus.active;
  }
}
