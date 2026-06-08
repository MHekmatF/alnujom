// Phase 25 premium uplift v2 — publisher lead analytics.
// PublisherAnalyticsRepository: abstract interface for the lead-analytics
// surface — one method per RPC. Constitution IX: pure Dart, no Supabase import.
import '../../../../core/errors/result.dart';
import '../entities/publisher_lead_analytics.dart';

abstract class PublisherAnalyticsRepository {
  /// The per-listing lead breakdown for the authenticated publisher, ordered as
  /// returned by the RPC (busiest first).
  Future<Result<List<PublisherListingLeadAnalytics>>> fetchListingBreakdown();

  /// The trailing [days]-day daily lead trend, gap-filled (one entry per
  /// calendar day, oldest → newest) by the implementation.
  Future<Result<List<PublisherDailyLeadTotal>>> fetchDailyTotals({
    int days = 30,
  });
}
