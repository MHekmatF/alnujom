import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/inquiry_status.dart';
import '../repositories/inquiry_repository.dart';

@injectable
class UpdateInquiryStatus {
  const UpdateInquiryStatus(this._repository);

  final InquiryRepository _repository;

  /// Persists a status transition. Surfaces [TransitionInvalidFailure] when
  /// the enforce_inquiry_transition trigger rejects the mutation.
  Future<Result<void>> call(String inquiryId, InquiryStatus newStatus) =>
      _repository.updateStatus(inquiryId, newStatus);
}
