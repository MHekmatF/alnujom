import 'dart:ui' show Locale;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/cursor.dart';
import '../entities/home_listing_card.dart';
import '../repositories/home_feed_repository.dart';

/// Phase 13 — use case wrapping `HomeFeedRepository.fetchPage`. Pattern
/// matches Phase 10's `ListMyListings` (`lib/features/publisher_dashboard/
/// domain/usecases/list_my_listings.dart`).
@injectable
class LoadHomeFeed {
  const LoadHomeFeed(this._repository);

  final HomeFeedRepository _repository;

  Future<Result<List<HomeListingCard>>> call({
    Cursor? cursor,
    required Locale locale,
  }) {
    return _repository.fetchPage(cursor: cursor, locale: locale);
  }
}
