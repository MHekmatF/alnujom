import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/publisher_dashboard_repository.dart';

/// Renews a publisher's listing by extending its `expires_at` by [days] days
/// (defaults to 30). Owner-gated server-side via the `renew_listing` RPC.
/// On success returns the new `expires_at` timestamp so the caller can update
/// the listing in place; expired listings reappear in the public feed once
/// the new expiry is in the future.
@injectable
class RenewListing {
  const RenewListing(this._repository);

  final PublisherDashboardRepository _repository;

  Future<Result<DateTime?>> call({
    required String listingId,
    int days = 30,
  }) {
    return _repository.renewListing(listingId: listingId, days: days);
  }
}
