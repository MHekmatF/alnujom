import 'package:equatable/equatable.dart';

import 'listing.dart';

class ListingStatusHistoryEntry extends Equatable {
  const ListingStatusHistoryEntry({
    required this.id,
    required this.listingId,
    this.previousStatus,
    required this.newStatus,
    this.changedBy,
    required this.changedAt,
    this.reason,
  });

  final String id;
  final String listingId;
  final ListingStatus? previousStatus;
  final ListingStatus newStatus;
  final String? changedBy;
  final DateTime changedAt;
  final String? reason;

  @override
  List<Object?> get props => [
    id,
    listingId,
    previousStatus,
    newStatus,
    changedBy,
    changedAt,
    reason,
  ];
}
