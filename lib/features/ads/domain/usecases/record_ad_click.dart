// Phase 21 (spec/021-ads-banners) — RecordAdClick use case.
//
// Calls AdsServingRepository.recordClick which invokes the `record_ad_event`
// SECURITY DEFINER RPC (R-167). Best-effort — see FR-017.
//
// The tap handler MUST open the link target regardless of this call's outcome.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/ad_placement.dart';
import '../repositories/ads_serving_repository.dart';

@injectable
class RecordAdClick {
  const RecordAdClick(this._repository);

  final AdsServingRepository _repository;

  /// Records a click for [adId] in [placement]. Best-effort (FR-017).
  ///
  /// Returns [Success(null)] on success.
  /// Returns [FailureResult] on ad_not_eligible (23514) or network errors.
  /// Callers SHOULD ignore a failure and proceed to open the link target.
  Future<Result<void>> call({
    required String adId,
    required AdPlacement placement,
  }) =>
      _repository.recordClick(adId: adId, placement: placement);
}
