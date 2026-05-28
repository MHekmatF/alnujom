import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/favorites_repository.dart';

/// Phase 17 — removes a favorite via the `favorites_delete_self` RLS DELETE
/// policy. Emits no lead event (Q5=A).
@injectable
class RemoveFavorite {
  const RemoveFavorite(this._repository);

  final FavoritesRepository _repository;

  Future<Result<void>> call(String listingId) =>
      _repository.removeFavorite(listingId);
}
