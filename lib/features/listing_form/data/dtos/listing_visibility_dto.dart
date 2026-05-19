import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_visibility.dart';

class ListingVisibilityDto {
  const ListingVisibilityDto({
    required this.listingId,
    required this.locationVisibility,
    required this.contactVisibility,
    this.hideUntil,
    this.lastUpdatedBy,
    required this.updatedAt,
  });

  final String listingId;
  final String locationVisibility;
  final String contactVisibility;
  final DateTime? hideUntil;
  final String? lastUpdatedBy;
  final DateTime updatedAt;

  static ListingVisibilityDto fromMap(Map<String, dynamic> row) {
    return ListingVisibilityDto(
      listingId: row['listing_id'] as String,
      locationVisibility: row['location_visibility'] as String,
      contactVisibility: row['contact_visibility'] as String,
      hideUntil: row['hide_until'] != null
          ? DateTime.parse(row['hide_until'] as String)
          : null,
      lastUpdatedBy: row['last_updated_by'] as String?,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  ListingVisibilityEntity toEntity() {
    return ListingVisibilityEntity(
      listingId: listingId,
      locationVisibility: LocationVisibilityDb.fromDbValue(locationVisibility),
      contactVisibility:
          ContactNameVisibilityDb.fromDbValue(contactVisibility),
      hideUntil: hideUntil,
      lastUpdatedBy: lastUpdatedBy,
      updatedAt: updatedAt,
    );
  }
}
