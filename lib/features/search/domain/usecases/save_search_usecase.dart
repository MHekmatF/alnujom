// lib/features/search/domain/usecases/save_search_usecase.dart
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/filter_state.dart';
import '../entities/saved_search.dart';
import '../repositories/saved_searches_repository.dart';

/// Phase 25 — persists the current filters under a user-supplied label.
@injectable
class SaveSearchUseCase {
  const SaveSearchUseCase(this._repository);

  final SavedSearchesRepository _repository;

  Future<Result<SavedSearch>> call({
    required String label,
    required FilterState filters,
  }) => _repository.save(label: label, filters: filters);
}
