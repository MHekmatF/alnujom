// lib/features/viewings/domain/usecases/update_viewing_status.dart
//
// Viewing scheduler — use case: confirm/decline/cancel a viewing.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/viewing.dart';
import '../repositories/viewings_repository.dart';

@injectable
class UpdateViewingStatus {
  const UpdateViewingStatus(this._repository);

  final ViewingsRepository _repository;

  Future<Result<void>> call({
    required String viewingId,
    required ViewingStatus status,
  }) => _repository.updateStatus(
    viewingId: viewingId,
    status: status.wire,
  );
}
