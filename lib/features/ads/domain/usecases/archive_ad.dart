// Phase 21 (spec/021-ads-banners) — ArchiveAd use case.
//
// Calls AdsAdminRepository.archiveAd which invokes the `archive_ad`
// SECURITY DEFINER RPC (soft-delete via archived_at — R-170).
// Requires `ads.manage` permission.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/ads_admin_repository.dart';

@injectable
class ArchiveAd {
  const ArchiveAd(this._repository);

  final AdsAdminRepository _repository;

  /// Soft-deletes the ad by setting `archived_at = now()`.
  ///
  /// Returns [Success(null)] on success.
  Future<Result<void>> call(String adId) => _repository.archiveAd(adId);
}
