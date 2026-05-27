import '../../../../core/errors/result.dart';
import '../entities/inquiry.dart';
import '../entities/inquiry_status.dart';
import '../entities/inquiry_submission.dart';

abstract class InquiryRepository {
  /// Submits an inquiry. Returns the new inquiry id on success.
  Future<Result<String>> submitInquiry(InquirySubmission submission);

  /// Loads the publisher's inbox with optional filters and cursor-based pagination.
  ///
  /// [cursor] is an ISO-8601 timestamp string used as a `.lt('created_at', cursor)`
  /// bound for keyset pagination (omit for the first page).
  Future<Result<List<Inquiry>>> loadInbox({
    InquiryStatus? statusFilter,
    String? listingIdFilter,
    String? cursor,
    int limit = 30,
  });

  /// Loads a single inquiry by id.
  Future<Result<Inquiry>> loadDetail(String inquiryId);

  /// Persists a status transition. Surfaces [TransitionInvalidFailure] when
  /// the transition trigger rejects the mutation (SQLSTATE 23514).
  Future<Result<void>> updateStatus(String inquiryId, InquiryStatus newStatus);

  /// Returns the count of `status='new'` inquiries on listings owned by the
  /// current user. Used to drive the home AppBar badge.
  Future<Result<int>> loadUnreadCount();
}
