// Phase 29 (029-crm-reels-growth) — W2: publisher dashboard charts state.
// Three-state loading / loaded / error for the dashboard charts section
// (leads/day, inquiries/day, viewings-by-status). Constitution IX: pure Dart.
import '../../domain/entities/publisher_lead_analytics.dart';

sealed class PublisherChartsState {
  const PublisherChartsState();
}

final class PublisherChartsLoading extends PublisherChartsState {
  const PublisherChartsLoading();
}

final class PublisherChartsLoaded extends PublisherChartsState {
  const PublisherChartsLoaded({
    required this.leadsByDay,
    required this.inquiriesByDay,
    required this.viewingsByStatus,
  });

  /// Gap-filled daily lead totals, oldest → newest.
  final List<PublisherDailyLeadTotal> leadsByDay;

  /// Gap-filled daily inquiry totals, oldest → newest.
  final List<PublisherDailyLeadTotal> inquiriesByDay;

  /// The caller's viewings grouped by status (empty buckets omitted).
  final List<PublisherStatusTotal> viewingsByStatus;
}

final class PublisherChartsError extends PublisherChartsState {
  const PublisherChartsError(this.message);
  final String message;
}
