import 'package:decimal/decimal.dart';

import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/entities/map_marker.dart';
import '../../domain/entities/marker_coordinates.dart';

/// Mirrors the v_listings_map_public row shape.
///
/// Column names from the view:
///   id, title, marker_lat, marker_lng, is_approximate, location_visibility,
///   primary_amount, primary_currency, main_image_path, property_type, purpose,
///   governorate_name_ar, governorate_name_en.
class MapMarkerDto {
  MapMarkerDto({
    required this.id,
    required this.title,
    required this.markerLat,
    required this.markerLng,
    required this.isApproximate,
    required this.primaryAmount,
    required this.primaryCurrency,
    required this.mainImagePath,
    required this.propertyType,
    required this.purpose,
    required this.governorateNameAr,
    required this.governorateNameEn,
  });

  factory MapMarkerDto.fromJson(Map<String, dynamic> json) => MapMarkerDto(
        id: json['id'] as String,
        title: json['title'] as String,
        markerLat: (json['marker_lat'] as num).toDouble(),
        markerLng: (json['marker_lng'] as num).toDouble(),
        isApproximate: json['is_approximate'] as bool,
        primaryAmount: Decimal.parse(json['primary_amount'].toString()),
        primaryCurrency: json['primary_currency'] as String,
        mainImagePath: json['main_image_path'] as String?,
        propertyType: PropertyType.values.firstWhere(
          (e) => e.toDbValue() == (json['property_type'] as String),
        ),
        purpose: ListingPurpose.values.firstWhere(
          (e) => e.toDbValue() == (json['purpose'] as String),
        ),
        governorateNameAr: (json['governorate_name_ar'] as String?) ?? '',
        governorateNameEn: (json['governorate_name_en'] as String?) ?? '',
      );

  final String id;
  final String title;
  final double markerLat;
  final double markerLng;
  final bool isApproximate;
  final Decimal primaryAmount;
  final String primaryCurrency;
  final String? mainImagePath;
  final PropertyType propertyType;
  final ListingPurpose purpose;
  final String governorateNameAr;
  final String governorateNameEn;

  MapMarker toEntity() => MapMarker(
        id: id,
        position: MarkerCoordinates(latitude: markerLat, longitude: markerLng),
        title: title,
        primaryAmount: primaryAmount,
        primaryCurrencyCode: primaryCurrency,
        mainImagePath: mainImagePath,
        propertyType: propertyType,
        purpose: purpose,
        isApproximate: isApproximate,
        governorateNameAr: governorateNameAr,
        governorateNameEn: governorateNameEn,
      );
}
