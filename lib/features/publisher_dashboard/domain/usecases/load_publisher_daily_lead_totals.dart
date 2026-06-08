// Phase 25 premium uplift v2 — publisher lead analytics.
// LoadPublisherDailyLeadTotals use-case: gap-filled daily lead trend.
// Constitution IX: pure Dart, no Supabase import.
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../entities/publisher_lead_analytics.dart';
import '../repositories/publisher_analytics_repository.dart';

@injectable
class LoadPublisherDailyLeadTotals {
  LoadPublisherDailyLeadTotals(this._repository);

  final PublisherAnalyticsRepository _repository;

  /// Trailing [days]-day window (defaults to the last 30 days).
  Future<Result<List<PublisherDailyLeadTotal>>> call({int days = 30}) {
    return _repository.fetchDailyTotals(days: days);
  }
}
