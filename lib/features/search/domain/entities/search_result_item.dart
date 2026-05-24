// lib/features/search/domain/entities/search_result_item.dart
import 'package:equatable/equatable.dart';
import '../../../listing_form/domain/entities/listing.dart';

class SearchResultItem extends Equatable {
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

  const SearchResultItem({
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
    this.mainImagePath,
    required this.publishedAt,
  });

  /// Phase 14 Sub-Phase F pre-work — used by [SupabaseSearchDatasource] to
  /// rewrite [mainImagePath] from a raw storage path (e.g.
  /// `listings/<uuid>/image.jpg`) into a full public URL so the presentation
  /// layer (`SearchResultCard` + `CachedNetworkImage`) can render it directly.
  /// Mirrors the Phase 13 `HomeListingCardDto.copyWithMainImageUrl` pattern.
  SearchResultItem copyWith({String? mainImagePath}) {
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
      mainImagePath: mainImagePath ?? this.mainImagePath,
      publishedAt: publishedAt,
    );
  }

  @override
  List<Object?> get props => [id];
}
