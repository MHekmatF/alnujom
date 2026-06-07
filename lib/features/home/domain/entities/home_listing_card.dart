import 'package:equatable/equatable.dart';

import '../../../listing_form/domain/entities/listing.dart';
import '../../../listing_form/domain/entities/listing_price.dart';

/// Phase 13 (spec/013-home-and-details) — read-side projection of one listing
/// card on the public HomePage feed.
///
/// Per data-model.md §2.3 and FR-017. Field set is intentionally minimal:
/// the home card surfaces title + type + purpose + governorate + city + primary
/// price + main image thumbnail + time-since-publish, and routes to the
/// details page on tap. Area-level location is reserved for the details page
/// (per FR-017).
///
/// The localized location names are resolved at DTO→entity mapping time per
/// the caller's `Locale` (data-model.md §2.2), so this entity holds the final
/// strings ready for display.
///
/// `publishedAt` is non-null per spec.md Edge Cases — Phase 10 RLS gates rows
/// on `status='approved'` which is only set by Phase 12's `approve_listing`
/// Edge Function which always sets `published_at = now()`.
class HomeListingCard extends Equatable {
  const HomeListingCard({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.purpose,
    required this.governorateNameLocalized,
    required this.cityNameLocalized,
    required this.primaryPrice,
    required this.mainImageStoragePath,
    required this.mainImageUrl,
    required this.publishedAt,
    this.agencyId,
    this.agencyName,
    this.agencyLogoUrl,
    this.rooms,
    this.bathrooms,
    this.areaSize,
    this.floor,
  });

  final String id;
  final String title;
  final PropertyType propertyType;
  final ListingPurpose purpose;
  final String governorateNameLocalized;
  final String cityNameLocalized;
  final ListingPrice primaryPrice;

  /// Nullable per Phase 11 FR-022 zero-image defensive guard. A row with no
  /// `listing_media` row of `is_main=true AND kind='image'` renders the Phase
  /// 2 image-placeholder per FR-031.
  final String? mainImageStoragePath;

  /// Resolved public URL for [mainImageStoragePath]. The datasource computes
  /// this via `supabase.storage.from('listing-images').getPublicUrl(...)` so
  /// the presentation layer remains Constitution IX-clean per FR-030.
  /// Same value as [mainImageStoragePath] but URL-rendered; null whenever
  /// [mainImageStoragePath] is null.
  final String? mainImageUrl;

  final DateTime publishedAt;

  /// Phase 19 (FR-022) — verified-agency badge fields. Populated ONLY when the
  /// listing is under an `approved` agency (else null → no badge per FR-023).
  final String? agencyId;
  final String? agencyName;

  /// Resolved public URL for the agency logo (agency-assets bucket); may be
  /// null even when [agencyId] is set (agency has no logo).
  final String? agencyLogoUrl;

  /// Phase 25 uplift v2 — key facts (columns on `listings`). Nullable: land has
  /// no rooms/bathrooms, etc. The card renders only the present ones.
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
    governorateNameLocalized,
    cityNameLocalized,
    primaryPrice,
    mainImageStoragePath,
    mainImageUrl,
    publishedAt,
    agencyId,
    agencyName,
    agencyLogoUrl,
    rooms,
    bathrooms,
    areaSize,
    floor,
  ];
}
