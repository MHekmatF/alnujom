// lib/features/notifications/domain/repositories/push_token_repository.dart
//
// Phase 22 — Abstract contract for push token lifecycle.
// Implemented by PushTokenRepositoryImpl (data layer).

import '../../../../core/errors/result.dart';

/// Repository for the `notification_tokens` table.
///
/// Writes are definer-RPC-only (R-182/R-191).  Token register/deregister is
/// driven by [AuthBloc] on auth-state transitions (PR phase, T039).
abstract interface class PushTokenRepository {
  /// Calls `register_notification_token` RPC (upsert by user+token pair).
  ///
  /// [platform] defaults to 'android' (Principle XI).
  /// Registration happens regardless of `account_status` (R-191) so a pending
  /// user still receives the "account approved/rejected" push.
  Future<Result<void>> register(String token, {String platform = 'android'});

  /// Calls `deregister_notification_token` RPC for this device's token only
  /// (per-device deregister — SC-011, R-191).
  Future<Result<void>> deregister(String token);
}
