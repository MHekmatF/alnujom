import 'package:decimal/decimal.dart';

import '../../../listing_form/domain/entities/listing.dart';
import '../../../listing_form/domain/entities/listing_price.dart';
import '../../../listing_form/domain/entities/listing_status_history_entry.dart';
import '../../domain/entities/publisher_listing.dart';

/// Flat row from `public.v_publisher_listings`.
///
/// View shape (per `data-model.md § View`):
/// - listing parent columns: `listing_id` (renamed from id), plus the rest of
///   `public.listings` columns with their original names
/// - `latest_history_*` (id, previous_status, new_status, changed_by,
///   changed_at, reason) — populated by a LEFT JOIN LATERAL on
///   listing_status_history; every listing has at least one history row per
///   the Phase 10 status-transition trigger, so these are practically
///   always present
/// - `primary_price_*` (id, currency_code, amount) — populated by a LEFT JOIN
///   on listing_prices WHERE is_primary=true; NULL until the prices step is
///   first saved
class PublisherListingDto {
  PublisherListingDto({
    required this.listingId,
    required this.publisherUserId,
    required this.agencyId,
    required this.purpose,
    required this.propertyType,
    required this.status,
    required this.title,
    required this.governorateId,
    required this.cityId,
    required this.areaId,
    required this.addressText,
    required this.latitude,
    required this.longitude,
    required this.locationVisibility,
    required this.phone,
    required this.whatsapp,
    required this.contactNameVisibility,
    required this.areaSize,
    required this.rooms,
    required this.bathrooms,
    required this.floor,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.expiresAt,
    required this.latestHistoryId,
    required this.latestHistoryPreviousStatus,
    required this.latestHistoryNewStatus,
    required this.latestHistoryChangedBy,
    required this.latestHistoryChangedAt,
    required this.latestHistoryReason,
    required this.primaryPriceId,
    required this.primaryPriceCurrencyCode,
    required this.primaryPriceAmount,
    required this.viewsCount,
  });

  // Listing parent columns
  final String listingId;
  final String publisherUserId;
  final String? agencyId;
  final String purpose;
  final String propertyType;
  final String status;
  final String title;
  final String? governorateId;
  final String? cityId;
  final String? areaId;
  final String? addressText;

  /// SEC-I1: `v_publisher_listings` no longer projects the coordinates
  /// (migration `20260901120001_gate_listing_coordinates.sql`), so these are
  /// ALWAYS null here. My Listings is a list screen and never rendered a pin;
  /// the edit form loads the owner's own coordinates through the gated
  /// `get_listing_coordinates` RPC. Kept (rather than deleted) so the DTO stays
  /// a faithful 1:1 of the `Listing` entity shape.
  final Decimal? latitude;
  final Decimal? longitude;
  final String locationVisibility;
  final String? phone;
  final String? whatsapp;
  final String contactNameVisibility;
  final Decimal? areaSize;
  final int? rooms;
  final int? bathrooms;
  final int? floor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  // latest_history_* columns
  final String? latestHistoryId;
  final String? latestHistoryPreviousStatus;
  final String? latestHistoryNewStatus;
  final String? latestHistoryChangedBy;
  final DateTime? latestHistoryChangedAt;
  final String? latestHistoryReason;

  // primary_price_* columns
  final String? primaryPriceId;
  final String? primaryPriceCurrencyCode;
  final Decimal? primaryPriceAmount;

  // Plan A35 — `views_count`: distinct viewers, all time (integer, never
  // null; the view coalesces to zero).
  final int viewsCount;

  static PublisherListingDto fromMap(Map<String, dynamic> row) {
    return PublisherListingDto(
      listingId: row['listing_id'] as String,
      publisherUserId: row['publisher_user_id'] as String,
      agencyId: row['agency_id'] as String?,
      // Defensive: a draft listing can carry a null purpose/property_type;
      // fall back to safe enum sentinels so My Listings renders instead of
      // throwing "Null is not a subtype of String".
      purpose: row['purpose'] as String? ?? 'sale',
      propertyType: row['property_type'] as String? ?? 'other',
      status: row['status'] as String,
      title: row['title'] as String? ?? '',
      governorateId: row['governorate_id'] as String?,
      cityId: row['city_id'] as String?,
      areaId: row['area_id'] as String?,
      addressText: row['address_text'] as String?,
      latitude: _decimalOrNull(row['latitude']),
      longitude: _decimalOrNull(row['longitude']),
      locationVisibility: row['location_visibility'] as String? ?? 'hidden',
      phone: row['phone'] as String?,
      whatsapp: row['whatsapp'] as String?,
      contactNameVisibility:
          row['contact_name_visibility'] as String? ?? 'public',
      areaSize: _decimalOrNull(row['area_size']),
      rooms: row['rooms'] as int?,
      bathrooms: row['bathrooms'] as int?,
      floor: row['floor'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      publishedAt: row['published_at'] != null
          ? DateTime.parse(row['published_at'] as String)
          : null,
      expiresAt: row['expires_at'] != null
          ? DateTime.parse(row['expires_at'] as String)
          : null,
      latestHistoryId: row['latest_history_id'] as String?,
      latestHistoryPreviousStatus:
          row['latest_history_previous_status'] as String?,
      latestHistoryNewStatus: row['latest_history_new_status'] as String?,
      latestHistoryChangedBy: row['latest_history_changed_by'] as String?,
      latestHistoryChangedAt: row['latest_history_changed_at'] != null
          ? DateTime.parse(row['latest_history_changed_at'] as String)
          : null,
      latestHistoryReason: row['latest_history_reason'] as String?,
      primaryPriceId: row['primary_price_id'] as String?,
      primaryPriceCurrencyCode: row['primary_price_currency_code'] as String?,
      primaryPriceAmount: _decimalOrNull(row['primary_price_amount']),
      viewsCount: (row['views_count'] as num?)?.toInt() ?? 0,
    );
  }

  PublisherListing toEntity() {
    final listing = Listing(
      id: listingId,
      publisherUserId: publisherUserId,
      agencyId: agencyId,
      purpose: ListingPurposeDb.fromDbValue(purpose),
      propertyType: PropertyTypeDb.fromDbValue(propertyType),
      status: ListingStatusDb.fromDbValue(status),
      title: title,
      governorateId: governorateId,
      cityId: cityId,
      areaId: areaId,
      addressText: addressText,
      latitude: latitude?.toDouble(),
      longitude: longitude?.toDouble(),
      locationVisibility: LocationVisibilityDb.fromDbValue(locationVisibility),
      phone: phone,
      whatsapp: whatsapp,
      contactNameVisibility: ContactNameVisibilityDb.fromDbValue(
        contactNameVisibility,
      ),
      areaSize: areaSize?.toDouble(),
      rooms: rooms,
      bathrooms: bathrooms,
      floor: floor,
      createdAt: createdAt,
      updatedAt: updatedAt,
      publishedAt: publishedAt,
      expiresAt: expiresAt,
    );

    final history = latestHistoryId == null || latestHistoryNewStatus == null
        ? null
        : ListingStatusHistoryEntry(
            id: latestHistoryId!,
            listingId: listingId,
            previousStatus: latestHistoryPreviousStatus == null
                ? null
                : ListingStatusDb.fromDbValue(latestHistoryPreviousStatus!),
            newStatus: ListingStatusDb.fromDbValue(latestHistoryNewStatus!),
            changedBy: latestHistoryChangedBy,
            changedAt: latestHistoryChangedAt ?? updatedAt,
            reason: latestHistoryReason,
          );

    final price =
        primaryPriceId == null ||
            primaryPriceCurrencyCode == null ||
            primaryPriceAmount == null
        ? null
        : ListingPrice(
            id: primaryPriceId!,
            listingId: listingId,
            currencyCode: primaryPriceCurrencyCode!,
            amount: primaryPriceAmount!,
            isPrimary: true,
            createdAt: createdAt,
          );

    return PublisherListing(
      listing: listing,
      latestStatusHistoryEntry: history,
      primaryPrice: price,
      viewsCount: viewsCount,
    );
  }
}

Decimal? _decimalOrNull(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return Decimal.parse(raw.toString());
  if (raw is String) return Decimal.parse(raw);
  return null;
}
