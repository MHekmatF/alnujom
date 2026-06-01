// Phase 20 (spec/020-admin-dashboard) — T014
// DashboardState: three-state loading / loaded / error.
// Constitution IX: pure Dart, no Supabase import.
import '../../domain/entities/dashboard_counts.dart';

sealed class DashboardState {
  const DashboardState();
}

/// Initial / loading state — tiles remain navigable (FR-012).
final class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

/// Counts successfully loaded (counts.field may still be null = not permitted).
final class DashboardLoaded extends DashboardState {
  const DashboardLoaded(this.counts);
  final DashboardCounts counts;
}

/// Fetch failed — tiles remain navigable; show retry affordance (FR-012).
final class DashboardError extends DashboardState {
  const DashboardError(this.message);
  final String message;
}
