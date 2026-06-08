import '../../../../core/errors/result.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../entities/moderation_history_entry.dart';
import '../entities/publisher_listing.dart';

abstract class PublisherDashboardRepository {
  Future<List<PublisherListing>> listMyListings({
    ListingStatus? statusFilter,
    int offset = 0,
    int limit = 20,
  });

  /// Renews [listingId] by extending its `expires_at` by [days] days (owner-
  /// gated server-side). Returns the new `expires_at` on success.
  Future<Result<DateTime?>> renewListing({
    required String listingId,
    int days = 30,
  });

  /// Phase 12 / US2 — full chronological moderation history for a listing.
  /// Consumed by the US6 moderation history page (Phase 8).
  Future<Result<List<ModerationHistoryEntry>>> loadModerationHistory(
    String listingId,
  );

  /// Phase 12 / US2 — most recent `rejected` entry for a listing, or null
  /// when none exist. Used by the `RejectionReasonBanner` on the publisher
  /// dashboard's Rejected filter (banner contract §Data input).
  Future<Result<ModerationHistoryEntry?>> loadMostRecentRejection(
    String listingId,
  );
}
