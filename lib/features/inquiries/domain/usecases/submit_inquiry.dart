import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/inquiry_submission.dart';
import '../repositories/inquiry_repository.dart';

@injectable
class SubmitInquiry {
  const SubmitInquiry(this._repository);

  final InquiryRepository _repository;

  /// Delegates to [InquiryRepository.submitInquiry].
  /// Returns the new inquiry UUID on success.
  Future<Result<String>> call(InquirySubmission submission) =>
      _repository.submitInquiry(submission);
}
