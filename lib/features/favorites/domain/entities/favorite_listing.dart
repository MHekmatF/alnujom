import 'package:equatable/equatable.dart';

import '../../../listing_form/domain/entities/listing.dart';

/// Phase 17 — the FavoritesPage card projection, mirroring the `v_favorites`
/// row shape.
///
/// Fields that are sourced via the LEFT JOIN to `public.listings` (title,
/// primaryAmount, primaryCurrency, mainImagePath, governorate/city names) are
/// nullable: when [isAvailable] is `false` those columns arrive as NULL from
/// the view (the listing is RLS-hidden because it left `approved`). Callers
/// MUST null-coalesce before display.
class FavoriteListing extends Equatable {
  const FavoriteListing({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.purpose,
    required this.primaryAmount,
    required this.primaryCurrency,
    required this.mainImagePath,
    required this.governorateNameAr,
    required this.governorateNameEn,
    required this.cityNameAr,
    required this.cityNameEn,
    required this.isAvailable,
    required this.favoritedAt,
    this.rooms,
    this.bathrooms,
    this.areaSize,
    this.floor,
  });

  /// The favorited listing UUID (`favorites.listing_id` / `v_favorites.id`).
  final String id;

  /// Listing headline title. Empty string when [isAvailable] is false (RLS-hidden).
  final String title;

  /// Property type enum from Phase 10.
  final PropertyType propertyType;

  /// Listing purpose enum from Phase 10.
  final ListingPurpose purpose;

  /// Primary price amount. Null when [isAvailable] is false.
  final num? primaryAmount;

  /// Primary price currency code (e.g. 'SYP', 'USD'). Null when [isAvailable] is false.
  final String? primaryCurrency;

  /// Supabase Storage path for the first listing image. Null when no image or
  /// when [isAvailable] is false.
  final String? mainImagePath;

  /// Governorate Arabic display name. Null when [isAvailable] is false.
  final String? governorateNameAr;

  /// Governorate English display name. Null when [isAvailable] is false.
  final String? governorateNameEn;

  /// City Arabic display name. Null when [isAvailable] is false.
  final String? cityNameAr;

  /// City English display name. Null when [isAvailable] is false.
  final String? cityNameEn;

  /// True when the listing is `approved` and within its publish window.
  /// False when the listing has left `approved` (sold/rented/rejected/paused/
  /// expired/deleted) and is RLS-hidden — drives the FR-025 indicator.
  final bool isAvailable;

  /// When the favorite row was created (`favorites.created_at`).
  final DateTime favoritedAt;

  /// Phase 25 uplift v2 — key facts (columns on `listings`, surfaced via
  /// `v_favorites`). All nullable: land has no rooms/bathrooms, and every spec
  /// is NULL when [isAvailable] is false (RLS-hidden listing). The card renders
  /// only the present ones.
  final int? rooms;
  final int? bathrooms;
  final double? areaSize;
  final int? floor;

  @override
  List<Object?> get props => [
    id,
    title,
    propertyType,
    purpose,
    primaryAmount,
    primaryCurrency,
    mainImagePath,
    governorateNameAr,
    governorateNameEn,
    cityNameAr,
    cityNameEn,
    isAvailable,
    favoritedAt,
    rooms,
    bathrooms,
    areaSize,
    floor,
  ];
}
