// Phase 19 (spec/019-agencies) — LoadAgencyListings use case.
//
// Pages through agency listings via public.v_listings_public (badge-augmented),
// cursor-paginated on published_at DESC. Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/agency_repository.dart';

@injectable
class LoadAgencyListings {
  const LoadAgencyListings(this._repository);

  final AgencyRepository _repository;

  /// [cursor] is an ISO-8601 `published_at` timestamp for keyset pagination.
  /// Pass `null` for the first page.
  Future<Result<List<Map<String, dynamic>>>> call({
    required String agencyId,
    String? cursor,
    int limit = 30,
  }) =>
      _repository.loadAgencyListings(
        agencyId: agencyId,
        cursor: cursor,
        limit: limit,
      );
}
