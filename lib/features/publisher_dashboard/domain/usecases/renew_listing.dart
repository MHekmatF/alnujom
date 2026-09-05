import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/publisher_dashboard_repository.dart';

/// Renews a publisher's listing by extending its `expires_at` by [days] days
/// (null = the configured validity period, decided server-side — plan A26). Owner-gated server-side via the `renew_listing` RPC.
/// On success returns the new `expires_at` timestamp so the caller can update
/// the listing in place; expired listings reappear in the public feed once
/// the new expiry is in the future.
@injectable
class RenewListing {
  const RenewListing(this._repository);

  final PublisherDashboardRepository _repository;

  Future<Result<DateTime?>> call({
    required String listingId,
    int? days,
  }) {
    return _repository.renewListing(listingId: listingId, days: days);
  }
}
