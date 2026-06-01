// Phase 21 (spec/021-ads-banners) — LoadAds use case.
//
// Reads all ads from `public.ads` (admin SELECT — requires ads.manage) joined
// with their placement assignments. Powers the AdsListPage.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/ad.dart';
import '../repositories/ads_admin_repository.dart';

@injectable
class LoadAds {
  const LoadAds(this._repository);

  final AdsAdminRepository _repository;

  /// Returns the list of [Ad] entities visible to the current admin.
  ///
  /// Pass [includeArchived] = true to include soft-deleted ads
  /// (shown under the "archived" filter in AdsListPage).
  Future<Result<List<Ad>>> call({bool includeArchived = false}) =>
      _repository.loadAds(includeArchived: includeArchived);
}
