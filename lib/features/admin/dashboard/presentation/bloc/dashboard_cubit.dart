// Phase 20 (spec/020-admin-dashboard) — T014
// DashboardCubit: loads the operational counters via LoadDashboardCounts.
// load() and refresh() share one code path (no duplication).
//
// Phase 22 (spec/022-notifications-realtime) — T041 (FR-015/FR-016):
// opens a `listings`+`reports` Realtime channel on load(); a relevant change
// triggers a DEBOUNCED refresh() (rapid events collapse to one re-fetch); the
// channel reconciles with a fresh fetch on every (re)subscribe so a change
// missed during a connection drop self-heals (SC-004). The channel + debounce
// timer are torn down on close() (no leak). Counts always come from a full
// `admin_dashboard_counts` fetch — no client-side incremental math (FR-016).
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/result.dart';
import '../../../../../core/network/realtime_signals.dart';
import '../../domain/usecases/load_dashboard_counts.dart';
import 'dashboard_state.dart';

@injectable
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._loadCounts, this._realtimeSignals)
    : super(const DashboardLoading());

  final LoadDashboardCounts _loadCounts;
  final RealtimeSignals _realtimeSignals;

  /// Collapse window for rapid Realtime events → one re-fetch (FR-015).
  static const _debounce = Duration(milliseconds: 400);

  RealtimeSubscriptionHandle? _channel;
  Timer? _debounceTimer;

  /// Loads counts on first entry (shows loading indicator while in-flight) and
  /// opens the admin-counter Realtime channel (idempotent — opened once).
  Future<void> load() {
    _openChannel();
    return _fetch();
  }

  /// Pull-to-refresh: re-fetches counts without resetting to loading state
  /// so tiles stay navigable and the previous count stays visible until the
  /// new one arrives (FR-012).
  Future<void> refresh() => _fetch();

  /// Opens the `listings`+`reports` Realtime channel once. A change debounces a
  /// refresh(); a (re)subscribe reconciles with an immediate fresh fetch.
  void _openChannel() {
    if (_channel != null) return;
    _channel = _realtimeSignals.subscribeTables(
      tables: const ['listings', 'reports'],
      onChange: _scheduleRefresh,
      onResubscribe: () => unawaited(refresh()),
    );
  }

  /// Debounces refresh() so a burst of Realtime events yields a single fetch.
  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(refresh()));
  }

  Future<void> _fetch() async {
    final result = await _loadCounts();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(DashboardLoaded(value));
      case FailureResult(:final failure):
        emit(DashboardError(failure.message));
    }
  }

  @override
  Future<void> close() async {
    _debounceTimer?.cancel();
    final channel = _channel;
    _channel = null;
    await channel?.cancel();
    return super.close();
  }
}
