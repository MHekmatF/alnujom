// Phase 21 (spec/021-ads-banners) — UpdateAd use case.
//
// Calls AdsAdminRepository.updateAd which invokes the `update_ad`
// SECURITY DEFINER RPC. Requires `ads.manage` permission.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/ads_admin_repository.dart';

@injectable
class UpdateAd {
  const UpdateAd(this._repository);

  final AdsAdminRepository _repository;

  /// Returns [Success(null)] on success.
  ///
  /// [placements] elements must be `{'placement_key': String, 'priority': int}`.
  Future<Result<void>> call({
    required String adId,
    required String title,
    required String imagePath,
    String? captionAr,
    String? captionEn,
    required String linkKind,
    required String linkValue,
    DateTime? startAt,
    DateTime? endAt,
    required bool isActive,
    required List<Map<String, dynamic>> placements,
  }) => _repository.updateAd(
    adId: adId,
    title: title,
    imagePath: imagePath,
    captionAr: captionAr,
    captionEn: captionEn,
    linkKind: linkKind,
    linkValue: linkValue,
    startAt: startAt,
    endAt: endAt,
    isActive: isActive,
    placements: placements,
  );
}
