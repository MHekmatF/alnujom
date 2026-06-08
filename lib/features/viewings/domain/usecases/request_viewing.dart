// lib/features/viewings/domain/usecases/request_viewing.dart
//
// Viewing scheduler — use case: request a viewing on a listing.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/viewings_repository.dart';

@injectable
class RequestViewing {
  const RequestViewing(this._repository);

  final ViewingsRepository _repository;

  Future<Result<String>> call({
    required String listingId,
    required DateTime scheduledAtUtc,
    String? note,
  }) => _repository.requestViewing(
    listingId: listingId,
    scheduledAtUtc: scheduledAtUtc,
    note: note,
  );
}
