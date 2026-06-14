import 'package:equatable/equatable.dart';

import '../../../listing_form/domain/entities/listing.dart';
import '../../../listing_form/domain/entities/listing_price.dart';
import '../../../listing_form/domain/entities/listing_status_history_entry.dart';

/// Composite entity for one row of `MyListingsPage`. The view
/// `public.v_publisher_listings` returns this shape already joined: parent
/// listing + most-recent status history + the is_primary price.
class PublisherListing extends Equatable {
  const PublisherListing({
    required this.listing,
    required this.latestStatusHistoryEntry,
    required this.primaryPrice,
  });

  final Listing listing;

  /// Defensively nullable — every Phase 10 listing has at least one history
  /// row (the status-transition trigger writes NULL→draft on INSERT), but
  /// the view's LEFT JOIN LATERAL allows a NULL fallback.
  final ListingStatusHistoryEntry? latestStatusHistoryEntry;

  /// Null until the publisher saves the prices step.
  final ListingPrice? primaryPrice;

  /// In-place edit: draft/rejected listings edit themselves directly.
  bool get isEditable =>
      listing.status == ListingStatus.draft ||
      listing.status == ListingStatus.rejected;

  /// Phase 031 (WS-B) — an APPROVED listing can be edited via a stay-live
  /// REVISION ("Edit (needs approval)"): tapping opens the existing edit route,
  /// where the form bloc detects `approved` and stages the edit into a revision
  /// while the live listing stays public. This is distinct from in-place
  /// [isEditable] (draft/rejected).
  bool get isRevisionEditable => listing.status == ListingStatus.approved;

  /// True when the card should route to the edit form at all (in-place OR
  /// stay-live revision).
  bool get canOpenEditForm => isEditable || isRevisionEditable;

  bool get hasRejectionReason =>
      listing.status == ListingStatus.rejected &&
      latestStatusHistoryEntry?.reason != null &&
      latestStatusHistoryEntry!.reason!.trim().isNotEmpty;

  @override
  List<Object?> get props => [listing, latestStatusHistoryEntry, primaryPrice];
}
