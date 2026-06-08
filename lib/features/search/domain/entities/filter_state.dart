// lib/features/search/domain/entities/filter_state.dart
import 'package:equatable/equatable.dart';
import '../../../listing_form/domain/entities/listing.dart';
import 'count_filter_mode.dart';
import 'display_mode.dart';

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

  /// Owner-vs-agency lister filter. `null` ⇒ any (both owner- and
  /// agency-listed), `true` ⇒ only agency-listed, `false` ⇒ only owner-listed.
  /// Serialized to the RPC's `p_is_agency` param (only when non-null) and to
  /// the `saved_searches.filters` JSONB under key `is_agency`.
  final bool? isAgency;

  /// Phase 25 — list vs. embedded-map presentation of the results. Purely a
  /// view concern: it is NOT sent to the search RPC, NOT counted as an active
  /// filter, and NOT persisted in [toJson] (saved searches restore filters,
  /// not the view mode).
  final DisplayMode displayMode;

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
    this.isAgency,
    this.displayMode = DisplayMode.list,
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
      areaSizeMax == null &&
      isAgency == null;

  /// Phase 15 G3: true when at least one filter dimension is active.
  /// Consumed by [MapEntryFromSearch.showFilterAlert] to show the
  /// filter-active alert dialog when the user taps "Show on map."
  bool get hasAnyActiveFilter =>
      purpose != null ||
      propertyType != null ||
      governorateId != null ||
      cityId != null ||
      areaId != null ||
      priceMin != null ||
      priceMax != null ||
      rooms != null ||
      bathrooms != null ||
      areaSizeMin != null ||
      areaSizeMax != null ||
      isAgency != null ||
      (query != null && query!.isNotEmpty);

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
    bool? isAgency,
    DisplayMode? displayMode,
    // Sentinel for clearing nullable fields
    bool clearQuery = false,
    bool clearPurpose = false,
    bool clearPropertyType = false,
    bool clearGovernorateId = false,
    bool clearCityId = false,
    bool clearAreaId = false,
    bool clearPriceMin = false,
    bool clearPriceMax = false,
    bool clearPriceCurrency = false,
    bool clearRooms = false,
    bool clearBathrooms = false,
    bool clearAreaSize = false,
    bool clearIsAgency = false,
  }) {
    return FilterState(
      query: clearQuery ? null : (query ?? this.query),
      purpose: clearPurpose ? null : (purpose ?? this.purpose),
      propertyType: clearPropertyType
          ? null
          : (propertyType ?? this.propertyType),
      governorateId: clearGovernorateId
          ? null
          : (governorateId ?? this.governorateId),
      cityId: clearCityId ? null : (cityId ?? this.cityId),
      areaId: clearAreaId ? null : (areaId ?? this.areaId),
      priceMin: clearPriceMin ? null : (priceMin ?? this.priceMin),
      priceMax: clearPriceMax ? null : (priceMax ?? this.priceMax),
      priceCurrency: clearPriceCurrency
          ? null
          : (priceCurrency ?? this.priceCurrency),
      rooms: clearRooms ? null : (rooms ?? this.rooms),
      roomsMode: roomsMode ?? this.roomsMode,
      bathrooms: clearBathrooms ? null : (bathrooms ?? this.bathrooms),
      bathroomsMode: bathroomsMode ?? this.bathroomsMode,
      areaSizeMin: clearAreaSize ? null : (areaSizeMin ?? this.areaSizeMin),
      areaSizeMax: clearAreaSize ? null : (areaSizeMax ?? this.areaSizeMax),
      isAgency: clearIsAgency ? null : (isAgency ?? this.isAgency),
      displayMode: displayMode ?? this.displayMode,
    );
  }

  /// Serializes the *filter* dimensions for the `saved_searches.filters` JSONB
  /// column. The view mode ([displayMode]) and the free-text [query] are
  /// intentionally omitted — a saved search captures structured filters; the
  /// label carries the user's intent and the view mode is a per-session
  /// concern. Only non-null dimensions are written so round-tripping through
  /// [fromJson] reconstructs the same predicates.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (query != null) json['query'] = query;
    if (purpose != null) json['purpose'] = purpose!.toDbValue();
    if (propertyType != null) json['property_type'] = propertyType!.toDbValue();
    if (governorateId != null) json['governorate_id'] = governorateId;
    if (cityId != null) json['city_id'] = cityId;
    if (areaId != null) json['area_id'] = areaId;
    if (priceMin != null) json['price_min'] = priceMin;
    if (priceMax != null) json['price_max'] = priceMax;
    if (priceCurrency != null) json['price_currency'] = priceCurrency;
    if (rooms != null) {
      json['rooms'] = rooms;
      json['rooms_mode'] = roomsMode.name;
    }
    if (bathrooms != null) {
      json['bathrooms'] = bathrooms;
      json['bathrooms_mode'] = bathroomsMode.name;
    }
    if (areaSizeMin != null) json['area_size_min'] = areaSizeMin;
    if (areaSizeMax != null) json['area_size_max'] = areaSizeMax;
    if (isAgency != null) json['is_agency'] = isAgency;
    return json;
  }

  /// Rehydrates a [FilterState] from a [toJson] map (the
  /// `saved_searches.filters` JSONB payload). Tolerates missing keys and
  /// unknown enum values (falls through to null / default) so a forward-stated
  /// or partially-written payload never crashes the re-apply flow.
  factory FilterState.fromJson(Map<String, dynamic> json) {
    double? readDouble(Object? v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
    int? readInt(Object? v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
    CountFilterMode readMode(Object? v) =>
        v == 'atLeast' ? CountFilterMode.atLeast : CountFilterMode.exactly;
    ListingPurpose? readPurpose(Object? v) {
      if (v is! String) return null;
      try {
        return ListingPurposeDb.fromDbValue(v);
      } catch (_) {
        return null;
      }
    }

    PropertyType? readType(Object? v) {
      if (v is! String) return null;
      try {
        return PropertyTypeDb.fromDbValue(v);
      } catch (_) {
        return null;
      }
    }

    return FilterState(
      query: json['query'] as String?,
      purpose: readPurpose(json['purpose']),
      propertyType: readType(json['property_type']),
      governorateId: json['governorate_id'] as String?,
      cityId: json['city_id'] as String?,
      areaId: json['area_id'] as String?,
      priceMin: readDouble(json['price_min']),
      priceMax: readDouble(json['price_max']),
      priceCurrency: json['price_currency'] as String?,
      rooms: readInt(json['rooms']),
      roomsMode: readMode(json['rooms_mode']),
      bathrooms: readInt(json['bathrooms']),
      bathroomsMode: readMode(json['bathrooms_mode']),
      areaSizeMin: readDouble(json['area_size_min']),
      areaSizeMax: readDouble(json['area_size_max']),
      isAgency: json['is_agency'] is bool ? json['is_agency'] as bool : null,
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
    isAgency,
    displayMode,
  ];
}
