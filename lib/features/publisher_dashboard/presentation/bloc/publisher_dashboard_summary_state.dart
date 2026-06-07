// Phase 25 premium uplift v2 — publisher summary dashboard.
// Three-state loading / loaded / error. Constitution IX: pure Dart.
import '../../domain/entities/publisher_dashboard_counts.dart';

sealed class PublisherDashboardSummaryState {
  const PublisherDashboardSummaryState();
}

/// Initial / first-load state — the stat grid shows skeletons.
final class PublisherDashboardSummaryLoading
    extends PublisherDashboardSummaryState {
  const PublisherDashboardSummaryLoading();
}

/// Counts successfully loaded.
final class PublisherDashboardSummaryLoaded
    extends PublisherDashboardSummaryState {
  const PublisherDashboardSummaryLoaded(this.counts);
  final PublisherDashboardCounts counts;
}

/// Fetch failed — quick-actions stay reachable; show a retry affordance.
final class PublisherDashboardSummaryError
    extends PublisherDashboardSummaryState {
  const PublisherDashboardSummaryError(this.message);
  final String message;
}
