// Phase 21 (spec/021-ads-banners) — LoadServingAds use case.
//
// Queries `public.v_ads_serving` for a specific placement. Powers [AdSlot].
// No permission gate — the view grants SELECT to anon + authenticated (R-166).
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/ad_placement.dart';
import '../entities/serving_ad.dart';
import '../repositories/ads_serving_repository.dart';

@injectable
class LoadServingAds {
  const LoadServingAds(this._repository);

  final AdsServingRepository _repository;

  /// Returns eligible [ServingAd]s for [placement] ordered by priority DESC.
  ///
  /// An empty list means no eligible ads → [AdSlot] renders [SizedBox.shrink].
  Future<Result<List<ServingAd>>> call(AdPlacement placement) =>
      _repository.loadServingAds(placement);
}
