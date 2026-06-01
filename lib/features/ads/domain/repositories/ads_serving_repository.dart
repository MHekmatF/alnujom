// Phase 21 (spec/021-ads-banners) — AdsServingRepository interface.
//
// Public-facing serving surface: query v_ads_serving per placement + record
// click events via the record_ad_event RPC (R-167).
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.
// The concrete implementation lives in data/repositories/.

import '../../../../core/errors/result.dart';
import '../entities/ad_placement.dart';
import '../entities/serving_ad.dart';

abstract interface class AdsServingRepository {
  /// Queries `public.v_ads_serving` filtered by [placement] and returns the
  /// eligible ads in priority order (`priority DESC`, stable tie-break).
  ///
  /// Returns an empty list when no eligible ads exist (FR-012 — caller renders
  /// `SizedBox.shrink()` in that case).
  ///
  /// Returns [FailureResult] on network errors.
  Future<Result<List<ServingAd>>> loadServingAds(AdPlacement placement);

  /// Calls the `record_ad_event(p_ad_id, p_placement_key)` SECURITY DEFINER
  /// RPC to record a click event. Best-effort — the caller MUST open the link
  /// target regardless of this call's outcome (FR-017).
  ///
  /// Returns [Success(null)] on success.
  /// Returns [FailureResult] on ad_not_eligible (23514) or network errors.
  /// The tap handler SHOULD swallow the failure and proceed to open the target.
  Future<Result<void>> recordClick({
    required String adId,
    required AdPlacement placement,
  });
}
