import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/favorites_repository.dart';

/// Phase 17 — calls `add_favorite(p_listing_id)` SECURITY DEFINER RPC via
/// the repository. Authenticated-only; approved listings only.
@injectable
class AddFavorite {
  const AddFavorite(this._repository);

  final FavoritesRepository _repository;

  Future<Result<void>> call(String listingId) =>
      _repository.addFavorite(listingId);
}
