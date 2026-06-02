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

  /// Subscribes to all changes on each of [tables] (admin counters consume
  /// `public.listings` + `public.reports`). One channel carries all tables.
  /// [onChange] fires on any relevant row event; [onResubscribe] fires on
  /// (re)subscribe so callers can reconcile with a fresh count fetch.
  RealtimeSubscriptionHandle subscribeTables({
    required List<String> tables,
    required void Function() onChange,
    void Function()? onResubscribe,
  });
}
