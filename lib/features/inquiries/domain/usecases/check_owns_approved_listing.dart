import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/inquiry_repository.dart';

/// Drives the home inbox-entry visibility gate (FR-019 / Q6=B): the entry is
/// shown to any user who owns ≥ 1 approved listing, regardless of unread count.
@injectable
class CheckOwnsApprovedListing {
  const CheckOwnsApprovedListing(this._repository);

  final InquiryRepository _repository;

  Future<Result<bool>> call() => _repository.ownsApprovedListing();
}
