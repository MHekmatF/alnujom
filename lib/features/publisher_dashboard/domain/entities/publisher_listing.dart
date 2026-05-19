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

  bool get isEditable =>
      listing.status == ListingStatus.draft ||
      listing.status == ListingStatus.rejected;

  bool get hasRejectionReason =>
      listing.status == ListingStatus.rejected &&
      latestStatusHistoryEntry?.reason != null &&
      latestStatusHistoryEntry!.reason!.trim().isNotEmpty;

  @override
  List<Object?> get props => [listing, latestStatusHistoryEntry, primaryPrice];
}
