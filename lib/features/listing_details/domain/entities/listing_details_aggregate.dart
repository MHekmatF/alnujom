import 'package:equatable/equatable.dart';

import '../../../../features/listing_form/domain/entities/listing.dart';
import '../../../../features/listing_form/domain/entities/listing_details.dart';
import '../../../../features/listing_form/domain/entities/listing_media.dart';
import '../../../../features/listing_form/domain/entities/listing_price.dart';
import '../../../../features/locations/domain/entities/area.dart';
import '../../../../features/locations/domain/entities/city.dart';
import '../../../../features/locations/domain/entities/governorate.dart';

/// Phase 13 (spec/013-home-and-details) — aggregate root for the listing
/// details page. Composes Phase 10 + Phase 11 + Phase 8 entities with a
/// publisher summary that projects ONLY `full_name` + `username` per
/// Constitution III + ADR-0001 (private Vault fields excluded).
class ListingDetailsAggregate extends Equatable {
  const ListingDetailsAggregate({
    required this.listing,
    required this.details,
    required this.prices,
    required this.media,
    required this.governorate,
    required this.city,
    required this.area,
    required this.publisher,
    this.deedType,
    this.finishLevel,
    this.verificationStatus,
    this.verifiedAt,
  });

  /// Phase 10 Listing entity (title, type, purpose, visibility flags, etc.)
  final Listing listing;

  /// Phase 10 ListingDetails entity (description, amenities, year_built, etc.)
  final ListingDetails details;

  /// Phase 10 prices. Sorted with isPrimary=true first.
  final List<ListingPrice> prices;

  /// Phase 11 media. Ordered by ordering ASC with isMain=true floated first.
  final List<ListingMedia> media;

  /// Phase 8 location entities.
  final Governorate governorate;
  final City city;
  final Area area;

  /// Publisher summary — projects ONLY full_name + username per ADR-0001.
  /// Private Vault columns (legal_name, national_id, private_contact_methods)
  /// are NOT projected; Phase 5 RLS would block them anyway.
  final PublisherSummary publisher;

  /// Phase 035 Stage 3 — Syria-native attributes + field-verification. All
  /// nullable; the detail page renders the deed/finish facts + موثّق trust block
  /// only when present.
  final String? deedType;
  final String? finishLevel;
  final String? verificationStatus;
  final DateTime? verifiedAt;

  /// Whether the listing is field-verified (drives the موثّق trust block).
  bool get isVerified => verificationStatus == 'verified';

  @override
  List<Object?> get props => [
    listing,
    details,
    prices,
    media,
    governorate,
    city,
    area,
    publisher,
    deedType,
    finishLevel,
    verificationStatus,
    verifiedAt,
  ];
}

/// Publisher summary value object. Projects ONLY the two safe columns
/// (`full_name` + `username`) from the `profiles` table per ADR-0001.
class PublisherSummary extends Equatable {
  const PublisherSummary({required this.fullName, this.username});

  final String fullName;
  final String? username;

  @override
  List<Object?> get props => [fullName, username];
}
