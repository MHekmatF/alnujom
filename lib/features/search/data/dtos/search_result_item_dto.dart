// lib/features/search/data/dtos/search_result_item_dto.dart
//
// Phase 14 — DTO that maps one row of the `public.search_result_row`
// composite type returned by the `search_listings` RPC (per
// contracts/phase14-search-listings-rpc.md) onto the domain
// [SearchResultItem] entity.
//
// The RPC projects 12 columns; the `property_type` / `purpose` columns are
// DB-side snake_case strings (e.g. `daily_rent`) so we route them through
// the Phase 10 `*Db.fromDbValue()` extensions (NOT `enum.values.byName`,
// which would mismatch `daily_rent` against the Dart `dailyRent` name).
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/search_result_item.dart';

class SearchResultItemDto {
  const SearchResultItemDto({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.purpose,
    required this.governorateNameAr,
    required this.governorateNameEn,
    required this.cityNameAr,
    required this.cityNameEn,
    required this.primaryAmount,
    required this.primaryCurrency,
    required this.mainImagePath,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final PropertyType propertyType;
  final ListingPurpose purpose;
  final String governorateNameAr;
  final String governorateNameEn;
  final String cityNameAr;
  final String cityNameEn;
  final double primaryAmount;
  final String primaryCurrency;
  final String? mainImagePath;
  final DateTime publishedAt;

  factory SearchResultItemDto.fromJson(Map<String, dynamic> json) {
    return SearchResultItemDto(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      propertyType:
          PropertyTypeDb.fromDbValue(json['property_type'] as String),
      purpose: ListingPurposeDb.fromDbValue(json['purpose'] as String),
      governorateNameAr: (json['governorate_name_ar'] as String?) ?? '',
      governorateNameEn: (json['governorate_name_en'] as String?) ?? '',
      cityNameAr: (json['city_name_ar'] as String?) ?? '',
      cityNameEn: (json['city_name_en'] as String?) ?? '',
      primaryAmount: (json['primary_amount'] as num).toDouble(),
      primaryCurrency: json['primary_currency'] as String,
      mainImagePath: json['main_image_path'] as String?,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }

  SearchResultItem toEntity() {
    return SearchResultItem(
      id: id,
      title: title,
      propertyType: propertyType,
      purpose: purpose,
      governorateNameAr: governorateNameAr,
      governorateNameEn: governorateNameEn,
      cityNameAr: cityNameAr,
      cityNameEn: cityNameEn,
      primaryAmount: primaryAmount,
      primaryCurrency: primaryCurrency,
      mainImagePath: mainImagePath,
      publishedAt: publishedAt,
    );
  }
}
