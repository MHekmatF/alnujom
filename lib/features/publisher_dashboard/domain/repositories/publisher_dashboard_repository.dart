import '../../../../core/errors/result.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../entities/moderation_history_entry.dart';
import '../entities/publisher_listing.dart';

abstract class PublisherDashboardRepository {
  /// The signed-in user id, or `null` when signed out. Exposed so presentation
  /// can narrow a Realtime subscription to this publisher's own rows (Plan A23)
  /// without reaching into the data layer — the same seam [ChatRepository]
  /// opens for `isMine`.
  String? get currentUserId;

  Future<List<PublisherListing>> listMyListings({
    ListingStatus? statusFilter,
    int offset = 0,
    int limit = 20,
  });

  /// Renews [listingId] by extending its `expires_at` by [days] days (owner-
  /// gated server-side). Returns the new `expires_at` on success.
  /// Moves one of the caller's own listings to [status] (plan A15). The server
  /// owns the transition table; a refused move comes back as a failure.
  Future<Result<void>> setOwnListingStatus({
    required String listingId,
    required ListingStatus status,
  });

  Future<Result<DateTime?>> renewListing({
    required String listingId,
    int? days,
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
