// lib/features/search/domain/repositories/saved_searches_repository.dart
//
// Phase 25 premium uplift — abstract contract for the owner-scoped
// `saved_searches` table. No Supabase SDK import in this domain interface; the
// concrete impl in the data layer is the sole consumer (Constitution IX).
import '../../../../core/errors/result.dart';
import '../entities/filter_state.dart';
import '../entities/saved_search.dart';

abstract class SavedSearchesRepository {
  /// Persists [filters] under [label] for the current user.
  ///
  /// - `FailureResult(PermissionDeniedFailure())` → caller is anonymous.
  /// - `FailureResult(NetworkFailure(...))` → transport error.
  Future<Result<SavedSearch>> save({
    required String label,
    required FilterState filters,
  });

  /// Returns the current user's saved searches, newest-first.
  Future<Result<List<SavedSearch>>> list();

  /// Deletes a saved search by id.
  Future<Result<void>> delete(String id);
}
