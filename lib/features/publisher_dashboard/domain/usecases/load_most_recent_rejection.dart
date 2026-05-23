import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/moderation_history_entry.dart';
import '../repositories/publisher_dashboard_repository.dart';

/// Phase 12 / US2 — focused query that returns ONLY the most recent
/// `new_status='rejected'` history row for a single listing, or null when
/// the listing has no rejection history.
///
/// Used by the `RejectionReasonBanner` on `MyListingsPage`'s Rejected
/// filter. Per analysis finding C3, the banner needs only the most-recent
/// rejection — a dedicated focused query avoids loading N history rows
/// per card on every render.
@injectable
class LoadMostRecentRejectionUseCase {
  LoadMostRecentRejectionUseCase(this._repository);

  final PublisherDashboardRepository _repository;

  Future<Result<ModerationHistoryEntry?>> call(String listingId) {
    return _repository.loadMostRecentRejection(listingId);
  }
}
