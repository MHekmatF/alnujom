// lib/features/search/domain/entities/filter_state.dart
import 'package:equatable/equatable.dart';
import '../../../listing_form/domain/entities/listing.dart';
import 'count_filter_mode.dart';

class FilterState extends Equatable {
  final String? query;
  final ListingPurpose? purpose;
  final PropertyType? propertyType;
  final String? governorateId;
  final String? cityId;
  final String? areaId;
  final double? priceMin;
  final double? priceMax;
  final String? priceCurrency;
  final int? rooms;
  final CountFilterMode roomsMode;
  final int? bathrooms;
  final CountFilterMode bathroomsMode;
  final double? areaSizeMin;
  final double? areaSizeMax;

  const FilterState({
    this.query,
    this.purpose,
    this.propertyType,
    this.governorateId,
    this.cityId,
    this.areaId,
    this.priceMin,
    this.priceMax,
    this.priceCurrency,
    this.rooms,
    this.roomsMode = CountFilterMode.exactly,
    this.bathrooms,
    this.bathroomsMode = CountFilterMode.exactly,
    this.areaSizeMin,
    this.areaSizeMax,
  });

  static const empty = FilterState();

  bool get isEmpty =>
      query == null &&
      purpose == null &&
      propertyType == null &&
      governorateId == null &&
      cityId == null &&
      areaId == null &&
      priceMin == null &&
      priceMax == null &&
      rooms == null &&
      bathrooms == null &&
      areaSizeMin == null &&
      areaSizeMax == null;

  FilterState copyWith({
    String? query,
    ListingPurpose? purpose,
    PropertyType? propertyType,
    String? governorateId,
    String? cityId,
    String? areaId,
    double? priceMin,
    double? priceMax,
    String? priceCurrency,
    int? rooms,
    CountFilterMode? roomsMode,
    int? bathrooms,
    CountFilterMode? bathroomsMode,
    double? areaSizeMin,
    double? areaSizeMax,
    // Sentinel for clearing nullable fields
    bool clearQuery = false,
    bool clearPurpose = false,
    bool clearPropertyType = false,
    bool clearGovernorateId = false,
    bool clearCityId = false,
    bool clearAreaId = false,
    bool clearPriceMin = false,
    bool clearPriceMax = false,
    bool clearRooms = false,
    bool clearBathrooms = false,
    bool clearAreaSize = false,
  }) {
    return FilterState(
      query: clearQuery ? null : (query ?? this.query),
      purpose: clearPurpose ? null : (purpose ?? this.purpose),
      propertyType:
          clearPropertyType ? null : (propertyType ?? this.propertyType),
      governorateId:
          clearGovernorateId ? null : (governorateId ?? this.governorateId),
      cityId: clearCityId ? null : (cityId ?? this.cityId),
      areaId: clearAreaId ? null : (areaId ?? this.areaId),
      priceMin: clearPriceMin ? null : (priceMin ?? this.priceMin),
      priceMax: clearPriceMax ? null : (priceMax ?? this.priceMax),
      priceCurrency: priceCurrency ?? this.priceCurrency,
      rooms: clearRooms ? null : (rooms ?? this.rooms),
      roomsMode: roomsMode ?? this.roomsMode,
      bathrooms: clearBathrooms ? null : (bathrooms ?? this.bathrooms),
      bathroomsMode: bathroomsMode ?? this.bathroomsMode,
      areaSizeMin: clearAreaSize ? null : (areaSizeMin ?? this.areaSizeMin),
      areaSizeMax: clearAreaSize ? null : (areaSizeMax ?? this.areaSizeMax),
    );
  }

  @override
  List<Object?> get props => [
        query,
        purpose,
        propertyType,
        governorateId,
        cityId,
        areaId,
        priceMin,
        priceMax,
        priceCurrency,
        rooms,
        roomsMode,
        bathrooms,
        bathroomsMode,
        areaSizeMin,
        areaSizeMax,
      ];
}
