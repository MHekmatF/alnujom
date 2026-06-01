// Phase 21 (spec/021-ads-banners) — SetAdActive use case.
//
// Calls AdsAdminRepository.setAdActive which invokes the `set_ad_active`
// SECURITY DEFINER RPC. Requires `ads.manage` permission.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/ads_admin_repository.dart';

@injectable
class SetAdActive {
  const SetAdActive(this._repository);

  final AdsAdminRepository _repository;

  /// Toggle the active state of an ad.
  ///
  /// Returns [Success(null)] on success.
  Future<Result<void>> call({
    required String adId,
    required bool isActive,
  }) =>
      _repository.setAdActive(adId: adId, isActive: isActive);
}
