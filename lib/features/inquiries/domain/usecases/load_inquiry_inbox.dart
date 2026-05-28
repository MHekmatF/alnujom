import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/inquiry.dart';
import '../entities/inquiry_status.dart';
import '../repositories/inquiry_repository.dart';

@injectable
class LoadInquiryInbox {
  const LoadInquiryInbox(this._repository);

  final InquiryRepository _repository;

  /// Loads the publisher's inbox with optional filters and cursor pagination.
  Future<Result<List<Inquiry>>> call({
    InquiryStatus? statusFilter,
    String? listingIdFilter,
    String? cursor,
    int limit = 30,
    bool adminTier = false,
  }) => _repository.loadInbox(
    statusFilter: statusFilter,
    listingIdFilter: listingIdFilter,
    cursor: cursor,
    limit: limit,
    adminTier: adminTier,
  );
}
