// Phase 20 (spec/020-admin-dashboard) — T014
// DashboardCubit: loads the operational counters via LoadDashboardCounts.
// NO Timer, NO Realtime subscription (FR-011/FR-020).
// load() and refresh() share one code path (no duplication).
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../../domain/usecases/load_dashboard_counts.dart';
import 'dashboard_state.dart';

@injectable
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._loadCounts) : super(const DashboardLoading());

  final LoadDashboardCounts _loadCounts;

  /// Loads counts on first entry (shows loading indicator while in-flight).
  Future<void> load() => _fetch();

  /// Pull-to-refresh: re-fetches counts without resetting to loading state
  /// so tiles stay navigable and the previous count stays visible until the
  /// new one arrives (FR-012).
  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    final result = await _loadCounts();
    switch (result) {
      case Success(:final value):
        emit(DashboardLoaded(value));
      case FailureResult(:final failure):
        emit(DashboardError(failure.message));
    }
  }
}
