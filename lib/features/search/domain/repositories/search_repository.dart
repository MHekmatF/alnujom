// lib/features/search/domain/repositories/search_repository.dart
import '../../../../core/errors/result.dart';
import '../entities/filter_state.dart';
import '../entities/search_cursor.dart';
import '../entities/search_result_item.dart';
import '../entities/sort_order.dart';

/// Phase 14 — abstract contract for the search RPC per FR-002 / FR-011.
///
/// Returns a `Result<List<SearchResultItem>>`:
/// - `Success([])` → no results for the given filters.
/// - `Success(rows)` where `rows.length < limit` → end of result set.
/// - `Success(rows)` where `rows.length == limit` → more pages may exist;
///   next page driven by passing the appropriate `SearchCursor`.
/// - `FailureResult(NetworkFailure(...))` → transport error.
///
/// No Supabase SDK import in this domain interface — the concrete
/// implementation (`SearchRepositoryImpl`) in the data layer is the sole
/// Supabase consumer (Constitution IX).
abstract class SearchRepository {
  Future<Result<List<SearchResultItem>>> search({
    required FilterState filters,
    required SortOrder sort,
    SearchCursor? cursor,
    int limit = 20,
  });
}
