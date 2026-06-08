import 'dart:ui' show Locale;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/home_listing_card.dart';
import '../repositories/home_feed_repository.dart';

/// Phase 25 (featured-listings treatment) — use case wrapping
/// `HomeFeedRepository.fetchFeatured`. Mirrors [LoadHomeFeed] so the
/// featured carousel reads through the same domain seam as the regular feed.
@injectable
class LoadFeaturedListings {
  const LoadFeaturedListings(this._repository);

  final HomeFeedRepository _repository;

  Future<Result<List<HomeListingCard>>> call({
    int limit = 10,
    required Locale locale,
  }) {
    return _repository.fetchFeatured(limit: limit, locale: locale);
  }
}
