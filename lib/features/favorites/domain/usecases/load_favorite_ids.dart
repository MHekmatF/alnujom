import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/favorites_repository.dart';

/// Phase 17 — loads the signed-in user's favorited listing ID strings from
/// `public.favorites`. Used by [FavoritesCubit] to hydrate the session set on
/// sign-in (R-110).
@injectable
class LoadFavoriteIds {
  const LoadFavoriteIds(this._repository);

  final FavoritesRepository _repository;

  Future<Result<List<String>>> call() => _repository.loadFavoriteIds();
}
