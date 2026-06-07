import 'package:equatable/equatable.dart';

import '../../../listing_form/domain/entities/listing.dart';
import '../../../listing_form/domain/entities/listing_price.dart';

/// Premium uplift v2 — read-side projection of one "similar listing" card in
/// the listing-detail page's bottom carousel.
///
/// Mirrors the home-feed card projection (same minimal field set) so the
/// compact carousel card can reuse the home/property-card visual language:
/// main image thumbnail, primary price, title, location, and the key facts
/// (beds·baths·area). Routes to the details page on tap.
///
/// The localized location names are resolved at DTO→entity mapping time per
/// the caller's `Locale`, so this entity holds the final display strings.
class SimilarListingCard extends Equatable {
  const SimilarListingCard({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.purpose,
    required this.governorateNameLocalized,
    required this.cityNameLocalized,
    required this.primaryPrice,
    required this.mainImageUrl,
    this.rooms,
    this.bathrooms,
    this.areaSize,
  });

  final String id;
  final String title;
  final PropertyType propertyType;
  final ListingPurpose purpose;
  final String governorateNameLocalized;
  final String cityNameLocalized;
  final ListingPrice primaryPrice;

  /// Resolved public URL for the listing's main image; null renders the
  /// placeholder per the shared image fallback.
  final String? mainImageUrl;

  /// Key facts (columns on `listings`). All nullable — the card renders only
  /// the present ones.
  final int? rooms;
  final int? bathrooms;
  final double? areaSize;

  @override
  List<Object?> get props => [
    id,
    title,
    propertyType,
    purpose,
    governorateNameLocalized,
    cityNameLocalized,
    primaryPrice,
    mainImageUrl,
    rooms,
    bathrooms,
    areaSize,
  ];
}
