import 'package:equatable/equatable.dart';

import 'listing.dart';

class SubmitListingResult extends Equatable {
  const SubmitListingResult({
    required this.listingId,
    required this.status,
    required this.submittedAt,
  });

  final String listingId;
  final ListingStatus status;
  final DateTime submittedAt;

  @override
  List<Object?> get props => [listingId, status, submittedAt];
}
