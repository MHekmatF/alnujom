import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/favorite_listing.dart';
import '../repositories/favorites_repository.dart';

/// Phase 17 — pages through the user's saved listings via `public.v_favorites`
/// (newest-first, cursor pagination on `favorited_at DESC` per R-117).
@injectable
class LoadFavorites {
  const LoadFavorites(this._repository);

  final FavoritesRepository _repository;

  /// [cursor] is an ISO-8601 `favorited_at` timestamp for keyset pagination.
  /// Pass `null` for the first page.
  Future<Result<List<FavoriteListing>>> call({
    String? cursor,
    int limit = 30,
  }) => _repository.loadFavorites(cursor: cursor, limit: limit);
}
