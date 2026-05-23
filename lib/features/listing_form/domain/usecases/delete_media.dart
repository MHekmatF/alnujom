import 'package:injectable/injectable.dart';

import '../repositories/listings_repository.dart';

/// Phase 11 — Per-thumbnail delete per R-38 ordering (Storage REMOVE first,
/// then SQL DELETE).
@injectable
class DeleteMedia {
  const DeleteMedia(this._repository);

  final ListingsRepository _repository;

  Future<void> call({required String mediaId}) {
    return _repository.deleteMedia(mediaId: mediaId);
  }
}
