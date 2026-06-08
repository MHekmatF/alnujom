// lib/features/viewings/domain/usecases/load_my_viewings.dart
//
// Viewing scheduler — use case: load the caller's viewings.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/viewing.dart';
import '../repositories/viewings_repository.dart';

@injectable
class LoadMyViewings {
  const LoadMyViewings(this._repository);

  final ViewingsRepository _repository;

  Future<Result<List<Viewing>>> call() => _repository.listMyViewings();
}
