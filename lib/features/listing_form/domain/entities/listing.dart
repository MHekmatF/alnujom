import 'package:equatable/equatable.dart';

enum ListingPurpose { sale, rent, dailyRent, investment }

extension ListingPurposeDb on ListingPurpose {
  String toDbValue() {
    switch (this) {
      case ListingPurpose.sale:
        return 'sale';
      case ListingPurpose.rent:
        return 'rent';
      case ListingPurpose.dailyRent:
        return 'daily_rent';
      case ListingPurpose.investment:
        return 'investment';
    }
  }

  static ListingPurpose fromDbValue(String v) {
    switch (v) {
      case 'sale':
        return ListingPurpose.sale;
      case 'rent':
        return ListingPurpose.rent;
      case 'daily_rent':
        return ListingPurpose.dailyRent;
      case 'investment':
        return ListingPurpose.investment;
      default:
        throw ArgumentError('Unknown listing purpose: $v');
    }
  }
}

enum PropertyType {
  apartment,
  villa,
  land,
  shop,
  office,
  farm,
  warehouse,
  other,
}

extension PropertyTypeDb on PropertyType {
  String toDbValue() {
    switch (this) {
      case PropertyType.apartment:
        return 'apartment';
      case PropertyType.villa:
        return 'villa';
      case PropertyType.land:
        return 'land';
      case PropertyType.shop:
        return 'shop';
      case PropertyType.office:
        return 'office';
      case PropertyType.farm:
        return 'farm';
      case PropertyType.warehouse:
        return 'warehouse';
      case PropertyType.other:
        return 'other';
    }
  }

  static PropertyType fromDbValue(String v) {
    switch (v) {
      case 'apartment':
        return PropertyType.apartment;
      case 'villa':
        return PropertyType.villa;
      case 'land':
        return PropertyType.land;
      case 'shop':
        return PropertyType.shop;
      case 'office':
        return PropertyType.office;
      case 'farm':
        return PropertyType.farm;
      case 'warehouse':
        return PropertyType.warehouse;
      case 'other':
        return PropertyType.other;
      default:
        throw ArgumentError('Unknown property type: $v');
    }
  }

  bool get isResidential =>
      this == PropertyType.apartment || this == PropertyType.villa;
}

enum ListingStatus {
  draft,
  pendingReview,
  approved,
  rejected,
  paused,
  sold,
  rented,
  expired,
  deleted,
}

extension ListingStatusDb on ListingStatus {
  String toDbValue() {
    switch (this) {
      case ListingStatus.draft:
        return 'draft';
      case ListingStatus.pendingReview:
        return 'pending_review';
      case ListingStatus.approved:
        return 'approved';
      case ListingStatus.rejected:
        return 'rejected';
      case ListingStatus.paused:
        return 'paused';
      case ListingStatus.sold:
        return 'sold';
      case ListingStatus.rented:
        return 'rented';
      case ListingStatus.expired:
        return 'expired';
      case ListingStatus.deleted:
        return 'deleted';
    }
  }

  static ListingStatus fromDbValue(String v) {
    switch (v) {
      case 'draft':
        return ListingStatus.draft;
      case 'pending_review':
        return ListingStatus.pendingReview;
      case 'approved':
        return ListingStatus.approved;
      case 'rejected':
        return ListingStatus.rejected;
      case 'paused':
        return ListingStatus.paused;
      case 'sold':
        return ListingStatus.sold;
      case 'rented':
        return ListingStatus.rented;
      case 'expired':
        return ListingStatus.expired;
      case 'deleted':
        return ListingStatus.deleted;
      default:
        throw ArgumentError('Unknown listing status: $v');
    }
  }
}

enum LocationVisibility { hidden, approximate, exact, adminOnly }

extension LocationVisibilityDb on LocationVisibility {
  String toDbValue() {
    switch (this) {
      case LocationVisibility.hidden:
        return 'hidden';
      case LocationVisibility.approximate:
        return 'approximate';
      case LocationVisibility.exact:
        return 'exact';
      case LocationVisibility.adminOnly:
        return 'admin_only';
    }
  }

  static LocationVisibility fromDbValue(String v) {
    switch (v) {
      case 'hidden':
        return LocationVisibility.hidden;
      case 'approximate':
        return LocationVisibility.approximate;
      case 'exact':
        return LocationVisibility.exact;
      case 'admin_only':
        return LocationVisibility.adminOnly;
      default:
        throw ArgumentError('Unknown location visibility: $v');
    }
  }
}

enum ContactNameVisibility { public, adminOnly }

extension ContactNameVisibilityDb on ContactNameVisibility {
  String toDbValue() {
    switch (this) {
      case ContactNameVisibility.public:
        return 'public';
      case ContactNameVisibility.adminOnly:
        return 'admin_only';
    }
  }

  static ContactNameVisibility fromDbValue(String v) {
    switch (v) {
      case 'public':
        return ContactNameVisibility.public;
      case 'admin_only':
        return ContactNameVisibility.adminOnly;
      default:
        throw ArgumentError('Unknown contact name visibility: $v');
    }
  }
}

class Listing extends Equatable {
  const Listing({
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
  final ListingPurpose purpose;
  final PropertyType propertyType;
  final ListingStatus status;
  final String title;
  final String? governorateId;
  final String? cityId;
  final String? areaId;
  final String? addressText;
  final double? latitude;
  final double? longitude;
  final LocationVisibility locationVisibility;
  final String? phone;
  final String? whatsapp;
  final ContactNameVisibility contactNameVisibility;
  final double? areaSize;
  final int? rooms;
  final int? bathrooms;
  final int? floor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  Listing copyWith({
    String? id,
    String? publisherUserId,
    Object? agencyId = _sentinel,
    ListingPurpose? purpose,
    PropertyType? propertyType,
    ListingStatus? status,
    String? title,
    Object? governorateId = _sentinel,
    Object? cityId = _sentinel,
    Object? areaId = _sentinel,
    Object? addressText = _sentinel,
    Object? latitude = _sentinel,
    Object? longitude = _sentinel,
    LocationVisibility? locationVisibility,
    Object? phone = _sentinel,
    Object? whatsapp = _sentinel,
    ContactNameVisibility? contactNameVisibility,
    Object? areaSize = _sentinel,
    Object? rooms = _sentinel,
    Object? bathrooms = _sentinel,
    Object? floor = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? publishedAt = _sentinel,
    Object? expiresAt = _sentinel,
  }) {
    return Listing(
      id: id ?? this.id,
      publisherUserId: publisherUserId ?? this.publisherUserId,
      agencyId: identical(agencyId, _sentinel)
          ? this.agencyId
          : agencyId as String?,
      purpose: purpose ?? this.purpose,
      propertyType: propertyType ?? this.propertyType,
      status: status ?? this.status,
      title: title ?? this.title,
      governorateId: identical(governorateId, _sentinel)
          ? this.governorateId
          : governorateId as String?,
      cityId: identical(cityId, _sentinel)
          ? this.cityId
          : cityId as String?,
      areaId: identical(areaId, _sentinel)
          ? this.areaId
          : areaId as String?,
      addressText: identical(addressText, _sentinel)
          ? this.addressText
          : addressText as String?,
      latitude: identical(latitude, _sentinel)
          ? this.latitude
          : latitude as double?,
      longitude: identical(longitude, _sentinel)
          ? this.longitude
          : longitude as double?,
      locationVisibility: locationVisibility ?? this.locationVisibility,
      phone: identical(phone, _sentinel) ? this.phone : phone as String?,
      whatsapp: identical(whatsapp, _sentinel)
          ? this.whatsapp
          : whatsapp as String?,
      contactNameVisibility:
          contactNameVisibility ?? this.contactNameVisibility,
      areaSize: identical(areaSize, _sentinel)
          ? this.areaSize
          : areaSize as double?,
      rooms: identical(rooms, _sentinel) ? this.rooms : rooms as int?,
      bathrooms: identical(bathrooms, _sentinel)
          ? this.bathrooms
          : bathrooms as int?,
      floor: identical(floor, _sentinel) ? this.floor : floor as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: identical(publishedAt, _sentinel)
          ? this.publishedAt
          : publishedAt as DateTime?,
      expiresAt: identical(expiresAt, _sentinel)
          ? this.expiresAt
          : expiresAt as DateTime?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    publisherUserId,
    agencyId,
    purpose,
    propertyType,
    status,
    title,
    governorateId,
    cityId,
    areaId,
    addressText,
    latitude,
    longitude,
    locationVisibility,
    phone,
    whatsapp,
    contactNameVisibility,
    areaSize,
    rooms,
    bathrooms,
    floor,
    createdAt,
    updatedAt,
    publishedAt,
    expiresAt,
  ];
}

const Object _sentinel = Object();
