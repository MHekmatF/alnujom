// Phase 22 (spec/022-notifications-realtime) — PR: Realtime wiring helper impl.
//
// The ONLY presentation-adjacent file that imports `package:supabase_flutter` for
// Realtime. Blocs depend on the abstract [RealtimeSignals] above; the Supabase SDK
// is contained here (Constitution IX). Mirrors the wrapper-impl pattern used by
// `supabase_client_wrapper_impl.dart`.

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../logging/app_logger.dart';
import 'realtime_signals.dart';

@LazySingleton(as: RealtimeSignals)
final class RealtimeSignalsImpl implements RealtimeSignals {
  RealtimeSignalsImpl(this._logger);

  static const _tag = 'RealtimeSignals';

  final AppLogger _logger;

  /// Returns the client, or `null` when `Supabase.initialize` was never called
  /// (no backend / degraded mode) — every subscribe method then no-ops.
  supabase.SupabaseClient? get _client {
    try {
      return supabase.Supabase.instance.client;
    } on Object {
      return null;
    }
  }

  @override
  RealtimeSubscriptionHandle subscribeUserRoles({
    required String userId,
    required void Function() onChange,
    void Function()? onResubscribe,
  }) {
    final client = _client;
    if (client == null) return const _NoopHandle();

    final name = 'phase22:user_roles:$userId';
    final channel = client.channel(name);
    channel.onPostgresChanges(
      event: supabase.PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_roles',
      filter: supabase.PostgresChangeFilter(
        type: supabase.PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => _safe(onChange),
    );
    return _subscribe(client, channel, name, onResubscribe);
  }

  @override
  RealtimeSubscriptionHandle subscribeTables({
    required List<String> tables,
    required void Function() onChange,
    void Function()? onResubscribe,
  }) {
    final client = _client;
    if (client == null) return const _NoopHandle();

    final name = 'phase22:tables:${tables.join('+')}';
    final channel = client.channel(name);
    for (final table in tables) {
      channel.onPostgresChanges(
        event: supabase.PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _safe(onChange),
      );
    }
    return _subscribe(client, channel, name, onResubscribe);
  }

  /// Subscribes [channel] and wires the SUBSCRIBED status to [onResubscribe]
  /// (reconcile on every (re)subscribe so a missed event during a drop self-heals).
  /// [name] is the caller-built channel name (used only for diagnostics — the
  /// SDK's `RealtimeChannel.topic` getter is `@internal`).
  RealtimeSubscriptionHandle _subscribe(
    supabase.SupabaseClient client,
    supabase.RealtimeChannel channel,
    String name,
    void Function()? onResubscribe,
  ) {
    channel.subscribe((status, error) {
      if (status == supabase.RealtimeSubscribeStatus.subscribed) {
        if (onResubscribe != null) _safe(onResubscribe);
      } else if (error != null) {
        _logger.warning(
          'Realtime channel $name status=$status',
          error: error,
          tag: _tag,
        );
      }
    });
    return _ChannelHandle(client, channel, name, _logger);
  }

  void _safe(void Function() fn) {
    try {
      fn();
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Realtime callback threw.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }
}

/// Live handle: `cancel()` removes the channel from the client (idempotent).
final class _ChannelHandle implements RealtimeSubscriptionHandle {
  _ChannelHandle(this._client, this._channel, this._name, this._logger);

  final supabase.SupabaseClient _client;
  final supabase.RealtimeChannel _channel;
  final String _name;
  final AppLogger _logger;
  bool _cancelled = false;

  @override
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    try {
      await _client.removeChannel(_channel);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Failed to remove Realtime channel $_name.',
        error: error,
        stackTrace: stackTrace,
        tag: 'RealtimeSignals',
      );
    }
  }
}

/// Null-object handle returned when Supabase is uninitialized (degraded mode).
final class _NoopHandle implements RealtimeSubscriptionHandle {
  const _NoopHandle();

  @override
  Future<void> cancel() async {}
}
