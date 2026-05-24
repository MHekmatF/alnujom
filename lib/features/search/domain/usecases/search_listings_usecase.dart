// lib/features/search/domain/usecases/search_listings_usecase.dart
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/filter_state.dart';
import '../entities/search_cursor.dart';
import '../entities/search_result_item.dart';
import '../entities/sort_order.dart';
import '../repositories/search_repository.dart';

/// Phase 14 — use case wrapping `SearchRepository.search`. Pattern matches
/// Phase 13's `LoadHomeFeed` (`lib/features/home/domain/usecases/load_home_feed.dart`).
@injectable
class SearchListingsUseCase {
  const SearchListingsUseCase(this._repository);

  final SearchRepository _repository;

  Future<Result<List<SearchResultItem>>> call({
    required FilterState filters,
    required SortOrder sort,
    SearchCursor? cursor,
    int limit = 20,
  }) {
    return _repository.search(
      filters: filters,
      sort: sort,
      cursor: cursor,
      limit: limit,
    );
  }
}
