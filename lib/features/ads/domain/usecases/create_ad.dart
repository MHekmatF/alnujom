// Phase 21 (spec/021-ads-banners) — CreateAd use case.
//
// Calls AdsAdminRepository.createAd which invokes the `create_ad`
// SECURITY DEFINER RPC. Requires `ads.manage` permission.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/ads_admin_repository.dart';

@injectable
class CreateAd {
  const CreateAd(this._repository);

  final AdsAdminRepository _repository;

  /// Returns the new ad UUID string on success.
  ///
  /// [placements] elements must be `{'placement_key': String, 'priority': int}`.
  Future<Result<String>> call({
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
  }) =>
      _repository.createAd(
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
