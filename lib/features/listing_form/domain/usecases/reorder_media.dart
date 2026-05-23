import 'package:injectable/injectable.dart';

import '../repositories/listings_repository.dart';

/// Phase 11 — Re-sequences `listing_media.ordering` for a list of media ids.
@injectable
class ReorderMedia {
  const ReorderMedia(this._repository);

  final ListingsRepository _repository;

  Future<void> call({
    required String listingId,
    required List<String> newOrderIds,
  }) {
    return _repository.reorderMedia(
      listingId: listingId,
      newOrderIds: newOrderIds,
    );
  }
}
