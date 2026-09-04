// Phase 22 (spec/022-notifications-realtime) — PR: Realtime wiring helper.
//
// `RealtimeSignals` is the single seam through which presentation-layer blocs
// (`AuthBloc`, `DashboardCubit`) consume Supabase Realtime, so those blocs never
// import `package:supabase_flutter` directly (Constitution IX — the SDK stays in
// `lib/core/network/**` + feature `data/` layers, never in domain or blocs).
//
// Each `subscribe*` method opens ONE channel filtered by the table's existing RLS
// and returns a [RealtimeSubscriptionHandle] the caller MUST `cancel()` to tear the
// channel down (no leaks — load-bearing for FR-015/FR-017). The implementation is a
// safe no-op when Supabase is not initialized (degraded mode — the app still boots).

/// Opaque handle to one open Realtime channel. `cancel()` removes the channel.
/// Idempotent — calling `cancel()` more than once is safe.
abstract interface class RealtimeSubscriptionHandle {
  Future<void> cancel();
}

/// One table on a [RealtimeSignals.subscribeTables] channel, optionally narrowed
/// server-side to the rows where [column] equals [value] (Plan A23).
///
/// **Narrow whenever the caller only cares about its own rows.** An unfiltered
/// binding makes the server send every change on the table to every subscriber
/// and run an RLS check per subscriber per event; the filter is applied before
/// either. A filter on a column that is not the primary key also needs
/// `REPLICA IDENTITY FULL` on the table, or UPDATE and DELETE events are
/// silently dropped while INSERT keeps working — see
/// `20260904120009_filter_the_publisher_dashboard.sql`.
final class RealtimeTableWatch {
  /// Every change on [table] — for callers that genuinely want them all, like
  /// the admin dashboard (a handful of admins, and they moderate everything).
  const RealtimeTableWatch.all(this.table) : column = null, value = null;

  /// Only rows where [column] equals [value].
  const RealtimeTableWatch.where(
    this.table, {
    required String this.column,
    required String this.value,
  });

  final String table;
  final String? column;
  final String? value;

  bool get isFiltered => column != null && value != null;

  /// Stable, collision-free part of a channel name.
  String get topicPart => isFiltered ? '$table[$column=$value]' : table;
}

abstract interface class RealtimeSignals {
  /// Subscribes to all changes (INSERT/UPDATE/DELETE) on `public.user_roles`
  /// filtered to the given [userId] (`user_id=eq.<userId>`). [onChange] fires on
  /// every relevant row event; [onResubscribe] fires once the channel reaches the
  /// SUBSCRIBED state (use it to reconcile, e.g. force a permission refresh so a
  /// change missed during a connection drop self-heals — FR-016/SC-004/SC-005).
  ///
  /// Returns a null-object handle (cancel = no-op) when Supabase is uninitialized.
  RealtimeSubscriptionHandle subscribeUserRoles({
    required String userId,
    required void Function() onChange,
    void Function()? onResubscribe,
  });

  /// Subscribes to changes on each of [watches] — all of a table's rows, or the
  /// subset a [RealtimeTableWatch.where] names. One channel carries them all.
  /// [onChange] fires on any relevant row event; [onResubscribe] fires on
  /// (re)subscribe so callers can reconcile with a fresh count fetch.
  ///
  /// The reconcile matters more than it looks: it is what keeps a counter
  /// correct across a dropped connection, and what covers a table that is not
  /// in the Realtime publication at all.
  RealtimeSubscriptionHandle subscribeTables({
    required List<RealtimeTableWatch> watches,
    required void Function() onChange,
    void Function()? onResubscribe,
  });
}
