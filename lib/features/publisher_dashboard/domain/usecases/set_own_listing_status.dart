import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../repositories/publisher_dashboard_repository.dart';

/// Moves one of the caller's own listings to a new lifecycle status —
/// sold, rented, paused, re-published, or (soft) deleted.
///
/// Every rule lives in the `set_own_listing_status` RPC: it checks that the
/// caller is the publisher and that the move is one of the allowed ones. The
/// helpers below only decide which buttons to *draw*; they are never the gate,
/// and a stale card that offers an impossible move simply gets a refusal.
@injectable
class SetOwnListingStatus {
  const SetOwnListingStatus(this._repository);

  final PublisherDashboardRepository _repository;

  Future<Result<void>> call({
    required String listingId,
    required ListingStatus status,
  }) {
    return _repository.setOwnListingStatus(
      listingId: listingId,
      status: status,
    );
  }

  /// The moves a publisher may make from [current], in the order they should be
  /// offered. Mirrors the RPC's transition table — keep the two in step.
  static List<ListingStatus> availableFrom(ListingStatus current) {
    return switch (current) {
      ListingStatus.approved => const [
        ListingStatus.sold,
        ListingStatus.rented,
        ListingStatus.paused,
      ],
      // Sold and rented are not terminal: a buyer backs out, a tenant does not
      // sign, or the wrong button was tapped. Re-listing keeps the original
      // approval and publication date rather than starting over.
      ListingStatus.paused ||
      ListingStatus.sold ||
      ListingStatus.rented => const [
        ListingStatus.approved,
        ListingStatus.deleted,
      ],
      // `expired` deliberately offers no re-publish — that is Renew's job,
      // which extends the existing approval.
      ListingStatus.draft ||
      ListingStatus.rejected ||
      ListingStatus.expired => const [ListingStatus.deleted],
      // A submission under review belongs to the moderator until they decide,
      // and a deleted row is already terminal.
      ListingStatus.pendingReview || ListingStatus.deleted => const [],
    };
  }

  /// True when the move should ask for confirmation first. Deleting is the only
  /// one a publisher cannot undo from the app.
  static bool isDestructive(ListingStatus status) =>
      status == ListingStatus.deleted;
}
