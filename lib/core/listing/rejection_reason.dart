// Phase 12 (spec/012-listing-approval) — the six Q3=A rejection-reason preset keys.
//
// Source of truth: specs/012-listing-approval/data-model.md §3.1
// Location: lib/core/listing/ (feature-neutral per analysis finding C2) so that
//           BOTH lib/features/admin/listing_review/ AND
//                lib/features/publisher_dashboard/ can import without
//                cross-feature coupling.
//
// Constitution IX-clean: pure Dart enum, no package:supabase_flutter import,
// no Flutter widget imports.
//
// The TypeScript array in supabase/functions/reject_listing/index.ts MUST
// stay byte-identical with these six keys in the same order (SC-024).

enum RejectionReason {
  missingOrLowQualityPhotos('missing_or_low_quality_photos'),
  incorrectLocation('incorrect_location'),
  unrealisticPrice('unrealistic_price'),
  incompleteDescription('incomplete_description'),
  duplicateListing('duplicate_listing'),
  other('other');

  const RejectionReason(this.key);

  /// Stable, locale-independent storage key written into
  /// `listing_status_history.reason` as part of the Q4=A JSON shape
  /// `{"preset":"<key>","detail":"<string|null>"}`.
  final String key;

  /// Parses a stored preset key back into the enum.
  ///
  /// Throws [ArgumentError] if the key does not match any known preset —
  /// any unknown key in the database represents data corruption or a future
  /// preset that this client version does not yet handle.
  static RejectionReason fromKey(String key) {
    return RejectionReason.values.firstWhere(
      (r) => r.key == key,
      orElse: () => throw ArgumentError('Unknown RejectionReason key: $key'),
    );
  }
}
