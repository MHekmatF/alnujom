import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/moderation_history_entry.dart';
import '../repositories/publisher_dashboard_repository.dart';

/// Phase 12 / US2 (forward-used by US6) — loads the full chronological
/// moderation history for a single listing.
///
/// Consumed by the US6 moderation history page (Phase 8). Phase 4 (US2)
/// also ships this use case so the contract is in place — the actual page
/// renders in Phase 8.
///
/// Server-side RLS on `public.listing_status_history` enforces
/// `publisher_user_id = auth.uid()`; no extra owner check is needed here.
@injectable
class LoadModerationHistoryUseCase {
  LoadModerationHistoryUseCase(this._repository);

  final PublisherDashboardRepository _repository;

  Future<Result<List<ModerationHistoryEntry>>> call(String listingId) {
    return _repository.loadModerationHistory(listingId);
  }
}
