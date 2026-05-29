// Phase 18 (spec/018-reports-moderation) — LoadMyReportForListing use case.
//
// Returns the most-recent report filed by the current user against a given
// listing, or null when none exists. Drives the reporter-status banner on the
// listing-details page (FR-023). Zero Supabase imports (Constitution IX).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/report.dart';
import '../repositories/reports_repository.dart';

@injectable
class LoadMyReportForListing {
  const LoadMyReportForListing(this._repository);

  final ReportsRepository _repository;

  Future<Result<Report?>> call(String listingId) =>
      _repository.loadMyReportForListing(listingId);
}
