// lib/features/search/domain/usecases/list_saved_searches_usecase.dart
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/saved_search.dart';
import '../repositories/saved_searches_repository.dart';

/// Phase 25 — loads the current user's saved searches (newest-first).
@injectable
class ListSavedSearchesUseCase {
  const ListSavedSearchesUseCase(this._repository);

  final SavedSearchesRepository _repository;

  Future<Result<List<SavedSearch>>> call() => _repository.list();
}
