import '../../domain/entities/listing_details.dart';

class ListingDetailsDto {
  const ListingDetailsDto({
    required this.listingId,
    this.description,
    this.amenities = const <String>[],
    this.yearBuilt,
    this.furnished,
    this.parking,
    required this.createdAt,
    required this.updatedAt,
  });

  final String listingId;
  final String? description;
  final List<String> amenities;
  final int? yearBuilt;
  final bool? furnished;
  final bool? parking;
  final DateTime createdAt;
  final DateTime updatedAt;

  static ListingDetailsDto fromMap(Map<String, dynamic> row) {
    final raw = row['amenities'];
    final amenities = raw is List
        ? raw.cast<String>()
        : <String>[];
    return ListingDetailsDto(
      listingId: row['listing_id'] as String,
      description: row['description'] as String?,
      amenities: amenities,
      yearBuilt: row['year_built'] as int?,
      furnished: row['furnished'] as bool?,
      parking: row['parking'] as bool?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  ListingDetails toEntity() {
    return ListingDetails(
      listingId: listingId,
      description: description,
      amenities: amenities,
      yearBuilt: yearBuilt,
      furnished: furnished,
      parking: parking,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
