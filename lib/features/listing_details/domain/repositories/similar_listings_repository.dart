import 'dart:ui' show Locale;

import '../../../../core/errors/result.dart';
import '../entities/similar_listing_card.dart';

/// Premium uplift v2 — abstract repository for the "similar listings" carousel
/// on the listing-details page.
///
/// Returns up to a small batch of approved listings matching the source
/// listing's property type + governorate (excluding the source itself). RLS is
/// the sole `status = approved` gate (consistent with the rest of the feature);
/// a hidden/expired listing simply won't appear.
abstract class SimilarListingsRepository {
  Future<Result<List<SimilarListingCard>>> fetchSimilar({
    required String listingId,
    required String propertyType,
    String? governorateId,
    required Locale locale,
    int limit,
  });
}
