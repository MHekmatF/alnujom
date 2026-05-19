import 'package:decimal/decimal.dart';

import '../../domain/entities/listing.dart';

class ListingDto {
  const ListingDto({
    required this.id,
    required this.publisherUserId,
    this.agencyId,
    required this.purpose,
    required this.propertyType,
    required this.status,
    required this.title,
    this.governorateId,
    this.cityId,
    this.areaId,
    this.addressText,
    this.latitude,
    this.longitude,
    required this.locationVisibility,
    this.phone,
    this.whatsapp,
    required this.contactNameVisibility,
    this.areaSize,
    this.rooms,
    this.bathrooms,
    this.floor,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.expiresAt,
  });

  final String id;
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

  static ListingDto fromMap(Map<String, dynamic> row) {
    return ListingDto(
      id: row['id'] as String,
      publisherUserId: row['publisher_user_id'] as String,
      agencyId: row['agency_id'] as String?,
      // purpose, property_type, title are nullable in the DB for drafts (the
      // submit_listing RPC enforces non-null at submit time per Q1). For the
      // in-memory Listing entity we default purpose='sale', property_type=
      // 'apartment', title='' — the basics step overwrites them.
      purpose: (row['purpose'] as String?) ?? 'sale',
      propertyType: (row['property_type'] as String?) ?? 'apartment',
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
    );
  }

  Listing toEntity() {
    return Listing(
      id: id,
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
      contactNameVisibility:
          ContactNameVisibilityDb.fromDbValue(contactNameVisibility),
      areaSize: areaSize?.toDouble(),
      rooms: rooms,
      bathrooms: bathrooms,
      floor: floor,
      createdAt: createdAt,
      updatedAt: updatedAt,
      publishedAt: publishedAt,
      expiresAt: expiresAt,
    );
  }
}

Decimal? _decimalOrNull(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return Decimal.parse(raw.toString());
  if (raw is String) return Decimal.parse(raw);
  return null;
}
