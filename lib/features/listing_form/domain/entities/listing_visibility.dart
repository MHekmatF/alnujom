import 'package:equatable/equatable.dart';

import 'listing.dart';

class ListingVisibilityEntity extends Equatable {
  const ListingVisibilityEntity({
    required this.listingId,
    required this.locationVisibility,
    required this.contactVisibility,
    this.hideUntil,
    this.lastUpdatedBy,
    required this.updatedAt,
  });

  final String listingId;
  final LocationVisibility locationVisibility;
  final ContactNameVisibility contactVisibility;
  final DateTime? hideUntil;
  final String? lastUpdatedBy;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    listingId,
    locationVisibility,
    contactVisibility,
    hideUntil,
    lastUpdatedBy,
    updatedAt,
  ];
}
