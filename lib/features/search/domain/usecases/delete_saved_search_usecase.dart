// lib/features/search/domain/usecases/delete_saved_search_usecase.dart
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/saved_searches_repository.dart';

/// Phase 25 — deletes a saved search by id.
@injectable
class DeleteSavedSearchUseCase {
  const DeleteSavedSearchUseCase(this._repository);

  final SavedSearchesRepository _repository;

  Future<Result<void>> call(String id) => _repository.delete(id);
}
