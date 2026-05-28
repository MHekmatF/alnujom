// lib/features/favorites/data/models/favorite_listing_dto.dart
//
// Phase 17 — DTO mirroring a row from `public.v_favorites`.
//
// CRITICAL NULL-tolerance: when `is_available=false` the listing columns
// (title, primary_amount, primary_currency, main_image_path, governorate/city
// names) arrive as NULL from the view because the listing is RLS-hidden.
// Every listing-derived field MUST null-coalesce — never force-unwrap.

import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/favorite_listing.dart';

/// DTO mirroring a row from `public.v_favorites`.
///
/// Columns projected by the view (14 columns):
///   id, favorited_at,
///   title, property_type, purpose,
///   primary_amount, primary_currency,
///   main_image_path,
///   governorate_name_ar, governorate_name_en,
///   city_name_ar, city_name_en,
///   is_available
class FavoriteListingDto {
  const FavoriteListingDto({
    required this.id,
    required this.favoritedAt,
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
  });

  final String id;
  final DateTime favoritedAt;

  // Listing columns — may be null when is_available=false (RLS-hidden).
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

  factory FavoriteListingDto.fromJson(Map<String, dynamic> json) {
    // is_available arrives as bool or null; default false.
    final available = json['is_available'] as bool? ?? false;

    // property_type / purpose: use a safe fallback when null (unavailable row).
    final propertyTypeRaw = json['property_type'] as String?;
    final purposeRaw = json['purpose'] as String?;

    return FavoriteListingDto(
      id: json['id'] as String,
      favoritedAt: DateTime.parse(json['favorited_at'] as String),

      // Null-coalesce: empty string for display when listing is RLS-hidden.
      title: json['title'] as String? ?? '',
      propertyType: propertyTypeRaw != null
          ? PropertyTypeDb.fromDbValue(propertyTypeRaw)
          : PropertyType.other,
      purpose: purposeRaw != null
          ? ListingPurposeDb.fromDbValue(purposeRaw)
          : ListingPurpose.sale,

      // Nullable — consumers must guard.
      primaryAmount: json['primary_amount'] as num?,
      primaryCurrency: json['primary_currency'] as String?,
      mainImagePath: json['main_image_path'] as String?,
      governorateNameAr: json['governorate_name_ar'] as String?,
      governorateNameEn: json['governorate_name_en'] as String?,
      cityNameAr: json['city_name_ar'] as String?,
      cityNameEn: json['city_name_en'] as String?,
      isAvailable: available,
    );
  }

  FavoriteListing toEntity() {
    return FavoriteListing(
      id: id,
      favoritedAt: favoritedAt,
      title: title,
      propertyType: propertyType,
      purpose: purpose,
      primaryAmount: primaryAmount,
      primaryCurrency: primaryCurrency,
      mainImagePath: mainImagePath,
      governorateNameAr: governorateNameAr,
      governorateNameEn: governorateNameEn,
      cityNameAr: cityNameAr,
      cityNameEn: cityNameEn,
      isAvailable: isAvailable,
    );
  }
}
