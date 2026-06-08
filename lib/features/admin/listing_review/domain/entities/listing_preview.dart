import 'package:equatable/equatable.dart';

import '../../../../listing_form/domain/entities/listing.dart';
import '../../../../listing_form/domain/entities/listing_details.dart';
import '../../../../listing_form/domain/entities/listing_media.dart';
import '../../../../listing_form/domain/entities/listing_price.dart';
import '../../../../locations/domain/entities/area.dart';
import '../../../../locations/domain/entities/city.dart';
import '../../../../locations/domain/entities/governorate.dart';

/// Phase 12 (spec/012-listing-approval) — full preview payload for the
/// `ListingPreviewPage`. Aggregates Phase 8/9/10/11 entities into one shape
/// so the page can render gallery + price + location + amenities + description
/// at full fidelity without further fetches.
///
/// `publisherDisplayName` is the snapshot of `profiles.full_name` (or a
/// fallback to phone) at preview-load time. We carry the snapshot rather than
/// a full `Profile` entity because the preview only needs the display string
/// and avoiding the full Profile keeps this aggregate Constitution-IX clean.
class ListingPreview extends Equatable {
  const ListingPreview({
    required this.listing,
    this.details,
    required this.prices,
    required this.media,
    this.governorate,
    this.city,
    this.area,
    required this.publisherDisplayName,
    this.featuredUntil,
  });

  final Listing listing;
  final ListingDetails? details;
  final List<ListingPrice> prices;
  final List<ListingMedia> media;

  /// Nullable because Phase 10 drafts may submit without a full location set;
  /// the preview page renders the location block only when all three are
  /// present.
  final Governorate? governorate;
  final City? city;
  final Area? area;

  final String publisherDisplayName;

  /// Phase 25 — `listings.featured_until` snapshot at preview-load time.
  /// A listing is FEATURED when this is non-null AND in the future; the
  /// preview page shows the current state + offers the feature/unfeature
  /// action (gated on `listings.edit_any`).
  final DateTime? featuredUntil;

  /// True when the listing is currently featured (non-null + future).
  bool get isFeatured =>
      featuredUntil != null && featuredUntil!.isAfter(DateTime.now());

  @override
  List<Object?> get props => [
    listing,
    details,
    prices,
    media,
    governorate,
    city,
    area,
    publisherDisplayName,
    featuredUntil,
  ];
}
