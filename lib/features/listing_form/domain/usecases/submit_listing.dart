import 'package:injectable/injectable.dart';

import '../entities/submit_listing_result.dart';
import '../repositories/listings_repository.dart';

@injectable
class SubmitListing {
  const SubmitListing(this._repository);

  final ListingsRepository _repository;

  /// Delegates to the repository's submit_listing wrapper which calls the
  /// SECURITY DEFINER RPC and decodes the success/failure JSON. Repository
  /// layer translates SQLSTATE 22023 with `missing_fields` payload into a
  /// typed `SubmitListingFailureException`.
  Future<SubmitListingResult> call(String listingId) {
    return _repository.submitListing(listingId);
  }
}
