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
//
// Plan A23 — both bindings are narrowed to THIS publisher's rows. Unfiltered,
// every listing edit and every inquiry anywhere in the system woke every open
// dashboard, and the server ran an RLS check per subscriber per event. The
// reconcile-on-resubscribe above is what makes the narrowing safe: even if a
// filtered event is missed, the counters are re-fetched whole.
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/network/realtime_signals.dart';
import '../../domain/repositories/publisher_dashboard_repository.dart';
import '../../domain/usecases/load_publisher_dashboard_counts.dart';
import 'publisher_dashboard_summary_state.dart';

@injectable
class PublisherDashboardSummaryCubit
    extends Cubit<PublisherDashboardSummaryState> {
  PublisherDashboardSummaryCubit(
    this._loadCounts,
    this._realtimeSignals,
    this._repository,
  ) : super(const PublisherDashboardSummaryLoading());

  final LoadPublisherDashboardCounts _loadCounts;
  final RealtimeSignals _realtimeSignals;
  final PublisherDashboardRepository _repository;

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
    final uid = _repository.currentUserId;
    // Signed out there is no dashboard to keep fresh, and an unfiltered channel
    // would be the very fan-out this replaced. Leave it closed; `load()` still
    // fetches, and the next `load()` after sign-in opens it.
    if (uid == null) return;
    _channel = _realtimeSignals.subscribeTables(
      watches: [
        RealtimeTableWatch.where(
          'listings',
          column: 'publisher_user_id',
          value: uid,
        ),
        // `inquiries.publisher_user_id` is denormalised for exactly this
        // (20260904120009) — the table carries no other column naming the
        // publisher.
        RealtimeTableWatch.where(
          'inquiries',
          column: 'publisher_user_id',
          value: uid,
        ),
      ],
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
