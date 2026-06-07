import 'dart:ui' show Locale;

import 'package:decimal/decimal.dart';

import '../../../listing_form/domain/entities/listing.dart';
import '../../../listing_form/domain/entities/listing_price.dart';
import '../../domain/entities/home_listing_card.dart';

/// Phase 13 — flat DTO for one home-feed row per data-model.md §2.2.
///
/// The embedded selects (`listing_prices!inner`, `listing_media`,
/// `governorate:governorates(display_name)`, `city:cities(display_name)`) map
/// onto the nested helper DTOs below. Locale resolution happens at
/// `toEntity(locale: ...)`-time per data-model.md §2.2 + Phase 12's
/// `pending_listing_summary_dto.dart` pattern.
class HomeListingCardDto {
  const HomeListingCardDto({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.purpose,
    required this.publishedAt,
    required this.primaryPrice,
    required this.mainImage,
    required this.mainImageUrl,
    required this.governorate,
    required this.city,
    this.agencyId,
    this.agencyName,
    this.agencyLogoPath,
    this.agencyLogoUrl,
    this.rooms,
    this.bathrooms,
    this.areaSize,
    this.floor,
  });

  final String id;
  final String title;
  final String propertyType; // enum string per Phase 10 §6.3
  final String purpose; // enum string per Phase 10 §6.3
  final DateTime publishedAt;
  final HomeListingPriceDto primaryPrice;

  /// Nullable per Phase 11 FR-022 zero-image defensive guard.
  final HomeListingMediaDto? mainImage;

  /// Resolved public URL for [mainImage]. The datasource computes this via
  /// `supabase.storage.from('listing-images').getPublicUrl(...)` so the
  /// presentation layer remains Constitution IX-clean. Null when [mainImage]
  /// is null.
  final String? mainImageUrl;

  /// Localization map from JSONB `display_name` column. Nullable defensively
  /// — Phase 8 governorate/city FKs are nullable on the listings row.
  final HomeListingLocationNameDto? governorate;
  final HomeListingLocationNameDto? city;

  /// Phase 19 (FR-022) — owning agency badge fields. Only populated when the
  /// listing is under an `approved` agency (others stay null → no badge).
  final String? agencyId;
  final String? agencyName;

  /// Raw `logo_path` storage path from the embedded agency row (resolved to a
  /// public URL by the datasource into [agencyLogoUrl]).
  final String? agencyLogoPath;

  /// Resolved public URL for the agency logo (agency-assets bucket).
  final String? agencyLogoUrl;

  /// Phase 25 uplift v2 — key facts (columns on `listings`). All nullable;
  /// the card renders only the ones present.
  final int? rooms;
  final int? bathrooms;
  final double? areaSize;
  final int? floor;

  /// Parses the embedded-selects projection shape from
  /// `SupabaseHomeFeedDatasource.fetchPage`. Defensive against missing
  /// nested rows.
  static HomeListingCardDto fromJson(Map<String, dynamic> row) {
    // listing_prices is filtered to is_primary=true via the embedded
    // `.eq('listing_prices.is_primary', true)`, so the array should contain
    // exactly one element under normal conditions. Defensive fallbacks:
    // pick the first row flagged is_primary, else the first row.
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
        'home-feed row missing primary listing_prices for listing ${row['id']}',
      );
    }

    // listing_media is filtered to is_main=true AND kind='image' via the
    // embedded `.eq(...)` filters. May be empty (zero-image listings) — Phase
    // 11 forbids zero-image submits but admin direct-SQL can produce them.
    final mediaRaw = row['listing_media'] as List<dynamic>?;
    HomeListingMediaDto? mainImage;
    if (mediaRaw != null && mediaRaw.isNotEmpty) {
      Map<String, dynamic>? mainRow;
      for (final m in mediaRaw) {
        if (m is Map && m['is_main'] == true) {
          mainRow = Map<String, dynamic>.from(m);
          break;
        }
      }
      mainRow ??= Map<String, dynamic>.from(mediaRaw.first as Map);
      final path = mainRow['storage_path'];
      if (path is String && path.isNotEmpty) {
        mainImage = HomeListingMediaDto(
          storagePath: path,
          ordering: (mainRow['ordering'] as int?) ?? 0,
        );
      }
    }

    final govMap = row['governorate'] as Map<String, dynamic>?;
    final cityMap = row['city'] as Map<String, dynamic>?;

    // Phase 19 (FR-022) — embedded agency row. Surface the badge ONLY when the
    // agency is approved (others get null → no badge per FR-023).
    final agencyMap = row['agency'] as Map<String, dynamic>?;
    String? agencyId;
    String? agencyName;
    String? agencyLogoPath;
    if (agencyMap != null && agencyMap['status'] == 'approved') {
      agencyId = agencyMap['id'] as String?;
      agencyName = agencyMap['name'] as String?;
      agencyLogoPath = agencyMap['logo_path'] as String?;
    }

    return HomeListingCardDto(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      propertyType: row['property_type'] as String,
      purpose: row['purpose'] as String,
      publishedAt: DateTime.parse(row['published_at'] as String),
      primaryPrice: HomeListingPriceDto(
        currencyCode: primaryRow['currency_code'] as String,
        amount: _decimal(primaryRow['amount']),
      ),
      mainImage: mainImage,
      mainImageUrl: null, // resolved by the datasource after fromJson.
      governorate: govMap == null
          ? null
          : HomeListingLocationNameDto.fromDisplayName(govMap['display_name']),
      city: cityMap == null
          ? null
          : HomeListingLocationNameDto.fromDisplayName(cityMap['display_name']),
      agencyId: agencyId,
      agencyName: agencyName,
      agencyLogoPath: agencyLogoPath,
      rooms: _toInt(row['rooms']),
      bathrooms: _toInt(row['bathrooms']),
      areaSize: _toDouble(row['area_size']),
      floor: _toInt(row['floor']),
    );
  }

  /// Returns a copy of this DTO with [mainImageUrl] populated. Called by
  /// the datasource after the URL has been resolved via `getPublicUrl()`.
  HomeListingCardDto copyWithMainImageUrl(String? url) {
    return HomeListingCardDto(
      id: id,
      title: title,
      propertyType: propertyType,
      purpose: purpose,
      publishedAt: publishedAt,
      primaryPrice: primaryPrice,
      mainImage: mainImage,
      mainImageUrl: url,
      governorate: governorate,
      city: city,
      agencyId: agencyId,
      agencyName: agencyName,
      agencyLogoPath: agencyLogoPath,
      agencyLogoUrl: agencyLogoUrl,
      rooms: rooms,
      bathrooms: bathrooms,
      areaSize: areaSize,
      floor: floor,
    );
  }

  /// Returns a copy with the resolved agency-logo public URL populated.
  HomeListingCardDto copyWithAgencyLogoUrl(String? url) {
    return HomeListingCardDto(
      id: id,
      title: title,
      propertyType: propertyType,
      purpose: purpose,
      publishedAt: publishedAt,
      primaryPrice: primaryPrice,
      mainImage: mainImage,
      mainImageUrl: mainImageUrl,
      governorate: governorate,
      city: city,
      agencyId: agencyId,
      agencyName: agencyName,
      agencyLogoPath: agencyLogoPath,
      agencyLogoUrl: url,
      rooms: rooms,
      bathrooms: bathrooms,
      areaSize: areaSize,
      floor: floor,
    );
  }

  /// Maps to the domain entity, resolving the localized location names per
  /// the active `locale` per data-model.md §2.2.
  ///
  /// The `ListingPrice` entity requires (id, listingId, createdAt, isPrimary)
  /// which are NOT projected by the home-feed SELECT (the card surface only
  /// needs amount + currency code). We synthesize placeholders:
  /// - `id = '${listing.id}:primary'` (never referenced by the card UI)
  /// - `listingId = listing.id`
  /// - `isPrimary = true` (by query construction)
  /// - `createdAt = publishedAt` (defensive non-null sentinel; card UI does
  ///   not surface price-row creation time)
  HomeListingCard toEntity({required Locale locale}) {
    return HomeListingCard(
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
        createdAt: publishedAt,
      ),
      mainImageStoragePath: mainImage?.storagePath,
      mainImageUrl: mainImageUrl,
      publishedAt: publishedAt,
      agencyId: agencyId,
      agencyName: agencyName,
      agencyLogoUrl: agencyLogoUrl,
      rooms: rooms,
      bathrooms: bathrooms,
      areaSize: areaSize,
      floor: floor,
    );
  }
}

class HomeListingPriceDto {
  const HomeListingPriceDto({required this.currencyCode, required this.amount});

  final String currencyCode;
  final Decimal amount;
}

class HomeListingMediaDto {
  const HomeListingMediaDto({
    required this.storagePath,
    required this.ordering,
  });

  final String storagePath;
  final int ordering;
}

class HomeListingLocationNameDto {
  const HomeListingLocationNameDto({required this.displayName});

  /// Bilingual `{"ar": "...", "en": "..."}` map per Phase 8 schema.
  final Map<String, String> displayName;

  static HomeListingLocationNameDto fromDisplayName(Object? raw) {
    if (raw is! Map) {
      return const HomeListingLocationNameDto(displayName: <String, String>{});
    }
    return HomeListingLocationNameDto(
      displayName: raw.map(
        (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
      ),
    );
  }

  /// R-18-style fallback chain: requested locale → other locale → em-dash.
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
  throw StateError('home-feed row has non-numeric price amount: $raw');
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
