import 'package:equatable/equatable.dart';

import '../../../favorites/domain/entities/favorite_listing.dart';
import '../../../listing_form/domain/entities/listing.dart';

/// A lightweight, self-contained snapshot of one listing selected for the
/// side-by-side comparison view.
///
/// Built from a [FavoriteListing] summary (see [ComparisonItem.fromFavorite])
/// so the comparison feature never re-fetches: it carries exactly the facts the
/// columns render (image, title, price, purpose, type, rooms, baths, area,
/// location). All listing-sourced fields are nullable because an unavailable
/// (RLS-hidden) favorite arrives with NULL columns; the UI null-coalesces.
class ComparisonItem extends Equatable {
  const ComparisonItem({
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
    this.rooms,
    this.bathrooms,
    this.areaSize,
  });

  /// Projects a favorites-list summary into a comparison snapshot — no fetch.
  factory ComparisonItem.fromFavorite(FavoriteListing fav) => ComparisonItem(
    id: fav.id,
    title: fav.title,
    propertyType: fav.propertyType,
    purpose: fav.purpose,
    primaryAmount: fav.primaryAmount,
    primaryCurrency: fav.primaryCurrency,
    mainImagePath: fav.mainImagePath,
    governorateNameAr: fav.governorateNameAr,
    governorateNameEn: fav.governorateNameEn,
    cityNameAr: fav.cityNameAr,
    cityNameEn: fav.cityNameEn,
    isAvailable: fav.isAvailable,
    rooms: fav.rooms,
    bathrooms: fav.bathrooms,
    areaSize: fav.areaSize,
  );

  final String id;
  final String title;
  final PropertyType propertyType;
  final ListingPurpose purpose;
  final num? primaryAmount;
  final String? primaryCurrency;
  final String? mainImagePath;
  final String? governorateNameAr;
  final String? governorateNameEn;
  final String? cityNameAr;
  final String? cityNameEn;
  final bool isAvailable;
  final int? rooms;
  final int? bathrooms;
  final double? areaSize;

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
    rooms,
    bathrooms,
    areaSize,
  ];
}
