import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/listing_details_aggregate.dart';
import '../repositories/listing_details_repository.dart';

/// Phase 13 (spec/013-home-and-details) — use case wrapping the repository
/// fetch for a single listing details aggregate.
///
/// The BLoC fires [LoadListingDetails.call] on [ListingDetailsLoadRequested].
@injectable
class LoadListingDetails {
  const LoadListingDetails(this._repository);

  final ListingDetailsRepository _repository;

  Future<Result<ListingDetailsAggregate>> call(String id) {
    return _repository.fetchListing(id);
  }
}
