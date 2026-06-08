// Phase 25 premium uplift v2 — publisher lead analytics.
// Three-state loading / loaded / error for the lead-analytics surface.
// Constitution IX: pure Dart.
import '../../domain/entities/publisher_lead_analytics.dart';

sealed class PublisherAnalyticsState {
  const PublisherAnalyticsState();
}

/// Initial / first-load state — the page shows skeletons.
final class PublisherAnalyticsLoading extends PublisherAnalyticsState {
  const PublisherAnalyticsLoading();
}

/// Both RPCs resolved — carries the combined payload.
final class PublisherAnalyticsLoaded extends PublisherAnalyticsState {
  const PublisherAnalyticsLoaded(this.analytics);
  final PublisherLeadAnalytics analytics;
}

/// Either RPC failed — show a retry affordance.
final class PublisherAnalyticsError extends PublisherAnalyticsState {
  const PublisherAnalyticsError(this.message);
  final String message;
}
