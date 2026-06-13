// Phase 29 (029-crm-reels-growth) — W2: admin analytics state.
// Three-state loading / loaded / error. Constitution IX: pure Dart.
import '../../domain/entities/admin_analytics.dart';

sealed class AdminAnalyticsState {
  const AdminAnalyticsState();
}

/// Initial / first-load state — the page shows skeletons.
final class AdminAnalyticsLoading extends AdminAnalyticsState {
  const AdminAnalyticsLoading();
}

/// All series resolved — carries the combined payload (any series may be empty
/// for an admin lacking that section's permission; the page shows an empty
/// hint per chart rather than an error).
final class AdminAnalyticsLoaded extends AdminAnalyticsState {
  const AdminAnalyticsLoaded(this.analytics);
  final AdminAnalytics analytics;
}

/// A transport-level failure (network etc.) on at least one series — show a
/// retry affordance. Permission gaps do NOT land here (they yield empty series).
final class AdminAnalyticsError extends AdminAnalyticsState {
  const AdminAnalyticsError(this.message);
  final String message;
}
