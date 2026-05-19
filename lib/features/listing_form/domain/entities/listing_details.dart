import 'package:equatable/equatable.dart';

class ListingDetails extends Equatable {
  const ListingDetails({
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

  ListingDetails copyWith({
    String? listingId,
    Object? description = _sentinel,
    List<String>? amenities,
    Object? yearBuilt = _sentinel,
    Object? furnished = _sentinel,
    Object? parking = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ListingDetails(
      listingId: listingId ?? this.listingId,
      description: identical(description, _sentinel)
          ? this.description
          : description as String?,
      amenities: amenities ?? this.amenities,
      yearBuilt: identical(yearBuilt, _sentinel)
          ? this.yearBuilt
          : yearBuilt as int?,
      furnished: identical(furnished, _sentinel)
          ? this.furnished
          : furnished as bool?,
      parking: identical(parking, _sentinel)
          ? this.parking
          : parking as bool?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    listingId,
    description,
    amenities,
    yearBuilt,
    furnished,
    parking,
    createdAt,
    updatedAt,
  ];
}

const Object _sentinel = Object();
