import '../../../features/listing_form/domain/entities/listing.dart';

/// Phase 035 — a presentation-only view model for [DsListingCard], decoupling
/// the unified card from any single feature entity (home feed, search results,
/// favorites, recently-viewed all map their row into this).
///
/// Fields for the operator-enforced verification programme (verified state,
/// freshness, deed type, responsiveness) are **nullable and stubbed** until the
/// Stage-3 backend lands them — the card simply omits any slot whose data is
/// absent, so the same widget renders correctly before and after Stage 3.
class DsListingCardData {
  const DsListingCardData({
    required this.id,
    required this.title,
    required this.priceText,
    required this.purpose,
    required this.locationText,
    this.imageUrl,
    this.pricePerMeterText,
    this.rooms,
    this.bathrooms,
    this.areaSize,
    this.floor,
    this.isFeatured = false,
    this.agencyId,
    this.agencyName,
    this.agencyLogoUrl,
    this.publishedAt,
    // ── Stage-3 verification slots (null until wired) ───────────────────────
    this.isVerified,
    this.verifiedAgoText,
    this.deedLabel,
    this.respondsWithinText,
    this.whatsappPhone,
  });

  final String id;
  final String title;

  /// Pre-formatted primary price (currency-resolved by the caller).
  final String priceText;
  final ListingPurpose purpose;

  /// Governorate · city (or a fuller area line in compact mode).
  final String locationText;
  final String? imageUrl;

  /// Optional secondary price line (e.g. `$/م²` for sale, `شهرياً` for rent).
  final String? pricePerMeterText;
  final int? rooms;
  final int? bathrooms;
  final num? areaSize;
  final int? floor;
  final bool isFeatured;
  final String? agencyId;
  final String? agencyName;
  final String? agencyLogoUrl;
  final DateTime? publishedAt;

  /// True = field-verified, false = explicitly unverified, null = programme not
  /// yet live (render neither the verified nor the "unverified" treatment).
  final bool? isVerified;
  final String? verifiedAgoText;
  final String? deedLabel;
  final String? respondsWithinText;

  /// E164 phone for a direct WhatsApp launch from the compact-row button; when
  /// null the button falls back to opening the listing detail.
  final String? whatsappPhone;
}
