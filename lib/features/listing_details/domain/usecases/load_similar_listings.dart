import 'dart:ui' show Locale;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/similar_listing_card.dart';
import '../repositories/similar_listings_repository.dart';

/// Premium uplift v2 — use case wrapping the repository fetch for the
/// "similar listings" carousel on the listing-details page.
///
/// The [SimilarListingsCubit] fires this once the detail aggregate has loaded
/// (it needs the source listing's property type + governorate).
@injectable
class LoadSimilarListings {
  const LoadSimilarListings(this._repository);

  final SimilarListingsRepository _repository;

  Future<Result<List<SimilarListingCard>>> call({
    required String listingId,
    required String propertyType,
    String? governorateId,
    required Locale locale,
    int limit = 8,
  }) {
    return _repository.fetchSimilar(
      listingId: listingId,
      propertyType: propertyType,
      governorateId: governorateId,
      locale: locale,
      limit: limit,
    );
  }
}
