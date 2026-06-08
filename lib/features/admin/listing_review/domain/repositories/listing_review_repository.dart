import 'package:equatable/equatable.dart';

import '../../../../../core/errors/result.dart';
import '../../../../../core/listing/rejection_reason.dart';
import '../entities/listing_preview.dart';
import '../entities/pending_listing_summary.dart';

/// Phase 12 (spec/012-listing-approval) — abstract repository for the admin
/// listing-review feature. Constitution IX: domain layer has zero Supabase
/// imports; the data-layer `ListingReviewRepositoryImpl` is the sole concrete
/// implementation.
///
/// `rejectListing` is wired in Phase 4 (US2) — Phase 3 ships an
/// `UnimplementedError` stub so the type signature compiles.
abstract class ListingReviewRepository {
  Future<Result<List<PendingListingSummary>>> loadPendingQueue({
    PendingQueueCursor? cursor,
    int limit = 20,
  });

  Future<Result<ListingPreview>> loadListingPreview(String listingId);

  Future<Result<ApproveResult>> approveListing(String listingId);

  Future<Result<RejectResult>> rejectListing(
    String listingId,
    RejectionReason preset,
    String? detail,
  );

  /// Features (or un-features) a listing for [days] days via the admin RPC
  /// `set_listing_featured`. `days <= 0` removes the featuring. Returns the new
  /// `featured_until` on success (null when featuring was removed).
  Future<Result<FeatureResult>> featureListing({
    required String listingId,
    required int days,
  });
}

/// Cursor for the pending-queue keyset pagination. Per analysis finding C8
/// (`phase12-admin-queue-page.md`), the cursor field is `listings.created_at`
/// (indexed). The id tiebreaker ensures total ordering across same-timestamp
/// rows.
class PendingQueueCursor extends Equatable {
  const PendingQueueCursor({
    required this.lastSubmittedAt,
    required this.lastId,
  });

  final DateTime lastSubmittedAt;
  final String lastId;

  @override
  List<Object?> get props => [lastSubmittedAt, lastId];
}

/// Returned by `approveListing` on HTTP 200. Per Q2=A `expiresAt` is always
/// null at approval time; future-spec admin settings (Phase 23) MAY override.
class ApproveResult extends Equatable {
  const ApproveResult({required this.publishedAt, this.expiresAt});

  final DateTime publishedAt;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [publishedAt, expiresAt];
}

/// Returned by `rejectListing` on HTTP 200. Phase 4 wires the rejection path.
class RejectResult extends Equatable {
  const RejectResult({required this.preset, this.detail});

  final RejectionReason preset;
  final String? detail;

  @override
  List<Object?> get props => [preset, detail];
}

/// Returned by `featureListing` on success. [featuredUntil] is the new
/// `listings.featured_until` value, or null when featuring was removed
/// (the request passed `days <= 0`).
class FeatureResult extends Equatable {
  const FeatureResult({this.featuredUntil});

  final DateTime? featuredUntil;

  /// True when the listing remains featured after the mutation (i.e. the
  /// returned `featured_until` is in the future).
  bool get isFeatured =>
      featuredUntil != null && featuredUntil!.isAfter(DateTime.now());

  @override
  List<Object?> get props => [featuredUntil];
}
