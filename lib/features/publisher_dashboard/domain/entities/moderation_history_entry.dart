import 'package:equatable/equatable.dart';

import '../../../../core/listing/rejection_reason.dart';
import '../../../listing_form/domain/entities/listing.dart';

/// Phase 12 (spec/012-listing-approval, US2 + US6) — one row of a listing's
/// moderation history, surfaced to the publisher (NOT the admin queue path).
///
/// Sourced from `public.listing_status_history`. The `reason` column is
/// Q4=A JSON-encoded TEXT (`{"preset":"<key>","detail":"<string|null>"}`)
/// when `newStatus == rejected`; the datasource decodes it into
/// [rejectionPreset] + [rejectionDetail]. For non-rejection rows both fields
/// are `null`.
///
/// Per FR-015 + Constitution VIII, the publisher-facing UI never displays
/// the admin's identity — this entity intentionally omits `changedBy`.
class ModerationHistoryEntry extends Equatable {
  const ModerationHistoryEntry({
    required this.id,
    required this.newStatus,
    required this.changedAt,
    this.previousStatus,
    this.rejectionPreset,
    this.rejectionDetail,
  });

  final String id;

  /// Null on the very first row (the `draft` INSERT) — Phase 10's status
  /// trigger writes `previous_status=NULL` for the seed row.
  final ListingStatus? previousStatus;

  final ListingStatus newStatus;
  final DateTime changedAt;

  /// Decoded from `(reason::jsonb)->>'preset'` — non-null only for
  /// `newStatus == ListingStatus.rejected` rows that were written through
  /// the Phase 12 `reject_listing` Edge Function.
  final RejectionReason? rejectionPreset;

  /// Decoded from `(reason::jsonb)->>'detail'` — null when the admin left
  /// the detail field empty (allowed for non-Other presets per Q5=A).
  final String? rejectionDetail;

  bool get hasRejection => rejectionPreset != null;

  @override
  List<Object?> get props => [
    id,
    previousStatus,
    newStatus,
    changedAt,
    rejectionPreset,
    rejectionDetail,
  ];
}
