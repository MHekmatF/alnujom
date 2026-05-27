import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/inquiry.dart';
import '../repositories/inquiry_repository.dart';

@injectable
class LoadInquiryDetail {
  const LoadInquiryDetail(this._repository);

  final InquiryRepository _repository;

  /// Loads a single inquiry by id.
  Future<Result<Inquiry>> call(String inquiryId) =>
      _repository.loadDetail(inquiryId);
}
