import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../../listing_form/domain/entities/listing.dart'
    show PropertyType, ListingPurpose;
import 'marker_coordinates.dart';

/// A single map marker. Phase 15 FR-001 minimal-projection: only the fields the
/// map and its preview popover render. No publisher contact details, no
/// description, no full media gallery, no address.
class MapMarker extends Equatable {
  const MapMarker({
    required this.id,
    required this.position,
    required this.title,
    required this.primaryAmount,
    required this.primaryCurrencyCode,
    required this.mainImagePath,
    required this.propertyType,
    required this.purpose,
    required this.isApproximate,
    required this.governorateNameAr,
    required this.governorateNameEn,
  });

  final String id;
  final MarkerCoordinates position;
  final String title;
  final Decimal primaryAmount;
  final String primaryCurrencyCode;
  final String? mainImagePath;
  final PropertyType propertyType;
  final ListingPurpose purpose;
  final bool isApproximate;
  final String governorateNameAr;
  final String governorateNameEn;

  @override
  List<Object?> get props => [
        id,
        position,
        title,
        primaryAmount,
        primaryCurrencyCode,
        mainImagePath,
        propertyType,
        purpose,
        isApproximate,
        governorateNameAr,
        governorateNameEn,
      ];
}
