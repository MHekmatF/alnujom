// Phase 25 premium uplift v2 — publisher lead analytics.
// LoadPublisherListingBreakdown use-case: per-listing lead breakdown.
// Constitution IX: pure Dart, no Supabase import.
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/publisher_lead_analytics.dart';
import '../repositories/publisher_analytics_repository.dart';

@injectable
class LoadPublisherListingBreakdown {
  LoadPublisherListingBreakdown(this._repository);

  final PublisherAnalyticsRepository _repository;

  Future<Result<List<PublisherListingLeadAnalytics>>> call() {
    return _repository.fetchListingBreakdown();
  }
}
