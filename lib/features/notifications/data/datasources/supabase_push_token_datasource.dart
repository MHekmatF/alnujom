// lib/features/notifications/data/datasources/supabase_push_token_datasource.dart
//
// Phase 22 — Supabase I/O for push token lifecycle.
//
// Principle IX: sole Supabase importer for the token feature.
// All RPC names are string-keyed so PD compiles without the DB applied.
//
// Operations:
//   - `rpc('register_notification_token')`   — upsert (idempotent)
//   - `rpc('deregister_notification_token')` — per-device DELETE

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

@injectable
class SupabasePushTokenDatasource {
  SupabasePushTokenDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// Calls `register_notification_token` RPC.
  ///
  /// Upserts on `(user_id, token)` conflict — sets `is_active = true` and
  /// refreshes `last_seen_at`.  Safe to call on every auth-state transition.
  Future<void> register(String token, {String platform = 'android'}) async {
    await _client.rpc(
      'register_notification_token',
      params: {'p_token': token, 'p_platform': platform},
    );
  }

  /// Calls `deregister_notification_token` RPC.
  ///
  /// Deletes the row for this device's token only — other devices belonging to
  /// the same user are unaffected (SC-011, R-191).
  Future<void> deregister(String token) async {
    await _client.rpc(
      'deregister_notification_token',
      params: {'p_token': token},
    );
  }
}
