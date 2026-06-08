// Phase 25 premium uplift v2 — publisher summary dashboard.
// PublisherDashboardSummaryCubit: loads the publisher KPIs via
// LoadPublisherDashboardCounts. load() and refresh() share one code path.
//
// Mirrors the admin DashboardCubit's Realtime pattern: opens a
// `listings`+`inquiries` channel on load(); a relevant change triggers a
// DEBOUNCED refresh() (rapid events collapse to one re-fetch); a (re)subscribe
// reconciles with a fresh fetch so a change missed during a drop self-heals.
// The channel + debounce timer are torn down on close() (no leak). Counts
// always come from a full RPC fetch — no client-side incremental math.
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/network/realtime_signals.dart';
import '../../domain/usecases/load_publisher_dashboard_counts.dart';
import 'publisher_dashboard_summary_state.dart';

@injectable
class PublisherDashboardSummaryCubit
    extends Cubit<PublisherDashboardSummaryState> {
  PublisherDashboardSummaryCubit(this._loadCounts, this._realtimeSignals)
    : super(const PublisherDashboardSummaryLoading());

  final LoadPublisherDashboardCounts _loadCounts;
  final RealtimeSignals _realtimeSignals;

  /// Collapse window for rapid Realtime events → one re-fetch.
  static const _debounce = Duration(milliseconds: 400);

  RealtimeSubscriptionHandle? _channel;
  Timer? _debounceTimer;

  /// Loads counts on first entry (skeletons while in-flight) and opens the
  /// publisher-counter Realtime channel (idempotent — opened once).
  Future<void> load() {
    _openChannel();
    return _fetch();
  }

  /// Pull-to-refresh: re-fetches without resetting to the loading skeleton so
  /// the previous figures stay visible until the new ones arrive.
  Future<void> refresh() => _fetch();

  void _openChannel() {
    if (_channel != null) return;
    _channel = _realtimeSignals.subscribeTables(
      tables: const ['listings', 'inquiries'],
      onChange: _scheduleRefresh,
      onResubscribe: () => unawaited(refresh()),
    );
  }

  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(refresh()));
  }

  Future<void> _fetch() async {
    final result = await _loadCounts();
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(PublisherDashboardSummaryLoaded(value));
      case FailureResult(:final failure):
        emit(PublisherDashboardSummaryError(failure.message));
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
