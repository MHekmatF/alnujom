import 'package:injectable/injectable.dart';

import '../repositories/listings_repository.dart';

@injectable
class DeleteDraft {
  const DeleteDraft(this._repository);

  final ListingsRepository _repository;

  /// Deletes the draft listing. Server-side RLS / status guard refuses if
  /// the row is not in `draft` status. Cascade deletes children.
  Future<void> call(String listingId) {
    return _repository.deleteDraft(listingId);
  }
}
