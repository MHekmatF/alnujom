import 'package:injectable/injectable.dart';

import '../entities/listing.dart';
import '../repositories/listings_repository.dart';

@injectable
class LoadOrCreateDraft {
  const LoadOrCreateDraft(this._repository);

  final ListingsRepository _repository;

  Future<Listing> call(String publisherUserId) async {
    final existing = await _repository.findDraftForPublisher(publisherUserId);
    if (existing != null) return existing;
    return _repository.insertDraft(publisherUserId);
  }
}
