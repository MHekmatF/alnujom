import 'package:decimal/decimal.dart';

import '../../../../features/listing_form/data/dtos/listing_details_dto.dart';
import '../../../../features/listing_form/data/dtos/listing_dto.dart';
import '../../../../features/listing_form/data/dtos/listing_media_dto.dart';
import '../../../../features/listing_form/domain/entities/listing.dart';
import '../../../../features/listing_form/domain/entities/listing_details.dart';
import '../../../../features/listing_form/domain/entities/listing_media.dart';
import '../../../../features/listing_form/domain/entities/listing_price.dart';
import '../../../../features/locations/domain/entities/area.dart';
import '../../../../features/locations/domain/entities/city.dart';
import '../../../../features/locations/domain/entities/governorate.dart';
import '../../domain/entities/listing_details_aggregate.dart';

/// Phase 13 (spec/013-home-and-details) — DTO parsing the embedded-selects
/// projection from data-model.md §3.1 returned by
/// [SupabaseListingDetailsDatasource.fetchListing].
///
/// The DTO builds all sub-DTOs inline (reusing Phase 10 + Phase 11 DTO logic)
/// and exposes a single [toEntity] factory returning [ListingDetailsAggregate].
class ListingDetailsAggregateDto {
  const ListingDetailsAggregateDto({
    required this.listing,
    required this.details,
    required this.prices,
    required this.media,
    required this.governorate,
    required this.city,
    required this.area,
    required this.publisher,
  });

  final Listing listing;
  final ListingDetails details;
  final List<ListingPrice> prices;
  final List<ListingMedia> media;
  final Governorate governorate;
  final City city;
  final Area area;
  final PublisherSummary publisher;

  /// Parses the raw PostgREST embedded-selects JSON per data-model.md §3.1.
  ///
  /// The query projects:
  ///   listing_details   — 1:1 (single-row list from Supabase)
  ///   listing_prices    — 1:N
  ///   listing_media     — 1:N
  ///   governorate / city / area — FK lookup (single nested object)
  ///   publisher (profiles!listings_publisher_user_id_fkey) — FK lookup
  factory ListingDetailsAggregateDto.fromJson(Map<String, dynamic> json) {
    // ── Core listing ───────────────────────────────────────────────────────
    final listing = ListingDto.fromMap(json).toEntity();

    // ── listing_details (1:1 returned as list) ─────────────────────────────
    final detailsRaw = json['listing_details'];
    final ListingDetails details;
    if (detailsRaw is List && detailsRaw.isNotEmpty) {
      details = ListingDetailsDto.fromMap(
        Map<String, dynamic>.from(detailsRaw.first as Map),
      ).toEntity();
    } else if (detailsRaw is Map) {
      // Defensive: some PostgREST versions return the row directly.
      details = ListingDetailsDto.fromMap(
        Map<String, dynamic>.from(detailsRaw),
      ).toEntity();
    } else {
      // Missing details — construct minimal defaults so the page still renders.
      details = ListingDetails(
        listingId: json['id'] as String,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // ── listing_prices ─────────────────────────────────────────────────────
    final pricesRaw = json['listing_prices'];
    final List<ListingPrice> prices;
    if (pricesRaw is List) {
      prices = pricesRaw
          .map((p) => _parsePrice(Map<String, dynamic>.from(p as Map)))
          .toList(growable: false);
    } else {
      prices = const [];
    }

    // Sort: is_primary first, then by created_at.
    final sortedPrices = [...prices]
      ..sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });

    // ── listing_media ──────────────────────────────────────────────────────
    final mediaRaw = json['listing_media'];
    final List<ListingMedia> media;
    if (mediaRaw is List) {
      media = mediaRaw
          .map((m) => ListingMediaDto.fromJson(
                Map<String, dynamic>.from(m as Map),
              ).toEntity())
          .toList(growable: false);
    } else {
      media = const [];
    }

    // Sort: is_main first, then ordering ASC per Phase 12 Q8=A ListingGallery.
    final sortedMedia = [...media]
      ..sort((a, b) {
        if (a.isMain != b.isMain) return a.isMain ? -1 : 1;
        return a.ordering.compareTo(b.ordering);
      });

    // ── governorate ────────────────────────────────────────────────────────
    final govRaw = json['governorate'];
    final Governorate governorate;
    if (govRaw is Map) {
      governorate = _parseGovernorate(Map<String, dynamic>.from(govRaw));
    } else {
      governorate = _fallbackGovernorate();
    }

    // ── city ───────────────────────────────────────────────────────────────
    final cityRaw = json['city'];
    final City city;
    if (cityRaw is Map) {
      city = _parseCity(Map<String, dynamic>.from(cityRaw), governorate.id);
    } else {
      city = _fallbackCity(governorate.id);
    }

    // ── area ───────────────────────────────────────────────────────────────
    final areaRaw = json['area'];
    final Area area;
    if (areaRaw is Map) {
      area = _parseArea(Map<String, dynamic>.from(areaRaw), city.id);
    } else {
      area = _fallbackArea(city.id);
    }

    // ── publisher ──────────────────────────────────────────────────────────
    // Projects ONLY full_name + username per ADR-0001.
    final pubRaw = json['publisher'];
    final PublisherSummary publisher;
    if (pubRaw is Map) {
      publisher = PublisherSummary(
        fullName: (pubRaw['full_name'] as String?) ?? '',
        username: pubRaw['username'] as String?,
      );
    } else {
      publisher = const PublisherSummary(fullName: '');
    }

    return ListingDetailsAggregateDto(
      listing: listing,
      details: details,
      prices: sortedPrices,
      media: sortedMedia,
      governorate: governorate,
      city: city,
      area: area,
      publisher: publisher,
    );
  }

  ListingDetailsAggregate toEntity() {
    return ListingDetailsAggregate(
      listing: listing,
      details: details,
      prices: prices,
      media: media,
      governorate: governorate,
      city: city,
      area: area,
      publisher: publisher,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static ListingPrice _parsePrice(Map<String, dynamic> row) {
    final amountRaw = row['amount'];
    final amount = amountRaw is num
        ? Decimal.parse(amountRaw.toString())
        : Decimal.parse(amountRaw as String);
    return ListingPrice(
      id: row['id'] as String? ?? '',
      listingId: row['listing_id'] as String? ?? '',
      currencyCode: row['currency_code'] as String,
      amount: amount,
      isPrimary: row['is_primary'] as bool? ?? false,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
    );
  }

  static Governorate _parseGovernorate(Map<String, dynamic> row) {
    return Governorate(
      id: row['id'] as String? ?? '',
      key: row['key'] as String? ?? '',
      displayName: _parseLocalizedName(row),
      isActive: row['is_active'] as bool? ?? true,
      isSystem: row['is_system'] as bool? ?? false,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : DateTime.now(),
    );
  }

  static City _parseCity(Map<String, dynamic> row, String governorateId) {
    return City(
      id: row['id'] as String? ?? '',
      governorateId: governorateId,
      key: row['key'] as String? ?? '',
      displayName: _parseLocalizedName(row),
      isActive: row['is_active'] as bool? ?? true,
      isSystem: row['is_system'] as bool? ?? false,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : DateTime.now(),
    );
  }

  static Area _parseArea(Map<String, dynamic> row, String cityId) {
    return Area(
      id: row['id'] as String? ?? '',
      cityId: cityId,
      key: row['key'] as String? ?? '',
      displayName: _parseLocalizedName(row),
      isActive: row['is_active'] as bool? ?? true,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// The embedded-select from governorates/cities/areas projects `name_ar`
  /// + `name_en` (not the jsonb `display_name` field). Map them to the
  /// entity's `displayName` map.
  static Map<String, String> _parseLocalizedName(Map<String, dynamic> row) {
    final ar = row['name_ar'] as String?;
    final en = row['name_en'] as String?;
    // Also support the jsonb display_name field used by Phase 8 admin routes.
    final displayName = row['display_name'];
    if (displayName is Map) {
      return Map<String, String>.from(displayName.cast<String, String>());
    }
    return {
      if (ar != null) 'ar': ar,
      if (en != null) 'en': en,
    };
  }

  // Fallback sentinels (empty governorate/city/area when FK is null).
  static Governorate _fallbackGovernorate() => Governorate(
    id: '',
    key: '',
    displayName: const {},
    isActive: false,
    isSystem: false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  static City _fallbackCity(String governorateId) => City(
    id: '',
    governorateId: governorateId,
    key: '',
    displayName: const {},
    isActive: false,
    isSystem: false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  static Area _fallbackArea(String cityId) => Area(
    id: '',
    cityId: cityId,
    key: '',
    displayName: const {},
    isActive: false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
