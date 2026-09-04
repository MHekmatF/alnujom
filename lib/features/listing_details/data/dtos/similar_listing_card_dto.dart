import 'dart:ui' show Locale;

import 'package:decimal/decimal.dart';

import '../../../listing_form/domain/entities/listing.dart';
import '../../../listing_form/domain/entities/listing_price.dart';
import '../../domain/entities/similar_listing_card.dart';

/// Premium uplift v2 — flat DTO for one "similar listing" row.
///
/// Parses the embedded-selects projection issued by
/// [SupabaseSimilarListingsDatasource.fetchSimilar] (same shape family as the
/// home-feed card query). Locale resolution happens at `toEntity(locale: ...)`.
class SimilarListingCardDto {
  const SimilarListingCardDto({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.purpose,
    required this.primaryPrice,
    required this.mainImageStoragePath,
    required this.mainImageUrl,
    required this.governorate,
    required this.city,
    this.rooms,
    this.bathrooms,
    this.areaSize,
  });

  final String id;
  final String title;
  final String propertyType; // enum string
  final String purpose; // enum string
  final SimilarListingPriceDto primaryPrice;

  /// Nullable per the zero-image defensive guard.
  final String? mainImageStoragePath;

  /// Resolved public URL for [mainImageStoragePath] (populated by the
  /// datasource after `fromJson`).
  final String? mainImageUrl;

  final SimilarListingLocationNameDto? governorate;
  final SimilarListingLocationNameDto? city;

  final int? rooms;
  final int? bathrooms;
  final double? areaSize;

  /// Parses the embedded-selects projection shape. Defensive against missing
  /// nested rows.
  static SimilarListingCardDto fromJson(Map<String, dynamic> row) {
    // listing_prices is filtered to is_primary=true via the embedded filter, so
    // the array should hold exactly one element. Defensive fallbacks: first row
    // flagged is_primary, else first row.
    final pricesRaw = row['listing_prices'] as List<dynamic>?;
    Map<String, dynamic>? primaryRow;
    if (pricesRaw != null && pricesRaw.isNotEmpty) {
      for (final p in pricesRaw) {
        if (p is Map && p['is_primary'] == true) {
          primaryRow = Map<String, dynamic>.from(p);
          break;
        }
      }
      primaryRow ??= Map<String, dynamic>.from(pricesRaw.first as Map);
    }
    if (primaryRow == null) {
      throw StateError(
        'similar-listing row missing primary listing_prices for ${row['id']}',
      );
    }

    // listing_media filtered to is_main=true AND kind='image'. May be empty.
    final mediaRaw = row['listing_media'] as List<dynamic>?;
    String? mainImagePath;
    if (mediaRaw != null && mediaRaw.isNotEmpty) {
      Map<String, dynamic>? mainRow;
      for (final m in mediaRaw) {
        if (m is Map && m['is_main'] == true) {
          mainRow = Map<String, dynamic>.from(m);
          break;
        }
      }
      mainRow ??= Map<String, dynamic>.from(mediaRaw.first as Map);
      // Plan A18 — `thumbnail_path` is the card-sized copy; prefer it and fall
      // back to the full file, mirroring the COALESCE the card VIEWS use.
      final thumb = mainRow['thumbnail_path'];
      final path = (thumb is String && thumb.isNotEmpty)
          ? thumb
          : mainRow['storage_path'];
      if (path is String && path.isNotEmpty) {
        mainImagePath = path;
      }
    }

    final govMap = row['governorate'] as Map<String, dynamic>?;
    final cityMap = row['city'] as Map<String, dynamic>?;

    return SimilarListingCardDto(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      propertyType: row['property_type'] as String,
      purpose: row['purpose'] as String,
      primaryPrice: SimilarListingPriceDto(
        currencyCode: primaryRow['currency_code'] as String,
        amount: _decimal(primaryRow['amount']),
      ),
      mainImageStoragePath: mainImagePath,
      mainImageUrl: null, // resolved by the datasource after fromJson.
      governorate: govMap == null
          ? null
          : SimilarListingLocationNameDto.fromDisplayName(
              govMap['display_name'],
            ),
      city: cityMap == null
          ? null
          : SimilarListingLocationNameDto.fromDisplayName(cityMap['display_name']),
      rooms: _toInt(row['rooms']),
      bathrooms: _toInt(row['bathrooms']),
      areaSize: _toDouble(row['area_size']),
    );
  }

  /// Returns a copy with [mainImageUrl] populated by the datasource.
  SimilarListingCardDto copyWithMainImageUrl(String? url) {
    return SimilarListingCardDto(
      id: id,
      title: title,
      propertyType: propertyType,
      purpose: purpose,
      primaryPrice: primaryPrice,
      mainImageStoragePath: mainImageStoragePath,
      mainImageUrl: url,
      governorate: governorate,
      city: city,
      rooms: rooms,
      bathrooms: bathrooms,
      areaSize: areaSize,
    );
  }

  /// Maps to the domain entity, resolving localized location names per [locale].
  ///
  /// `ListingPrice` requires (id, listingId, createdAt, isPrimary) which the
  /// card SELECT does not project; we synthesize harmless placeholders (the
  /// compact card only reads amount + currency code).
  SimilarListingCard toEntity({required Locale locale}) {
    return SimilarListingCard(
      id: id,
      title: title,
      propertyType: PropertyTypeDb.fromDbValue(propertyType),
      purpose: ListingPurposeDb.fromDbValue(purpose),
      governorateNameLocalized: governorate == null
          ? '—'
          : governorate!.localizedName(locale),
      cityNameLocalized: city == null ? '—' : city!.localizedName(locale),
      primaryPrice: ListingPrice(
        id: '$id:primary',
        listingId: id,
        currencyCode: primaryPrice.currencyCode,
        amount: primaryPrice.amount,
        isPrimary: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      mainImageUrl: mainImageUrl,
      rooms: rooms,
      bathrooms: bathrooms,
      areaSize: areaSize,
    );
  }
}

class SimilarListingPriceDto {
  const SimilarListingPriceDto({
    required this.currencyCode,
    required this.amount,
  });

  final String currencyCode;
  final Decimal amount;
}

class SimilarListingLocationNameDto {
  const SimilarListingLocationNameDto({required this.displayName});

  /// Bilingual `{"ar": "...", "en": "..."}` map per the locations schema.
  final Map<String, String> displayName;

  static SimilarListingLocationNameDto fromDisplayName(Object? raw) {
    if (raw is! Map) {
      return const SimilarListingLocationNameDto(
        displayName: <String, String>{},
      );
    }
    return SimilarListingLocationNameDto(
      displayName: raw.map(
        (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
      ),
    );
  }

  /// Fallback chain: requested locale → other locale → em-dash.
  String localizedName(Locale locale) {
    final preferred = displayName[locale.languageCode]?.trim();
    if (preferred != null && preferred.isNotEmpty) return preferred;
    final fallbackKey = locale.languageCode == 'ar' ? 'en' : 'ar';
    final fallback = displayName[fallbackKey]?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return '—';
  }
}

Decimal _decimal(Object? raw) {
  if (raw is num) return Decimal.parse(raw.toString());
  if (raw is String) return Decimal.parse(raw);
  throw StateError('similar-listing row has non-numeric price amount: $raw');
}

int? _toInt(Object? raw) {
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

double? _toDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}
