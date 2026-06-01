// lib/features/notifications/domain/usecases/register_push_token.dart
//
// Phase 22 — Use case: register this device's FCM token (FR-011, R-191).
// Called by AuthBloc on the Authenticated transition (PR phase, T039).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/push_token_repository.dart';

@injectable
class RegisterPushToken {
  const RegisterPushToken(this._repository);

  final PushTokenRepository _repository;

  /// Registers [token] for the signed-in user.
  ///
  /// [platform] defaults to 'android' per Principle XI.
  /// Idempotent — safe to call on every auth transition (upsert on conflict).
  Future<Result<void>> call(String token, {String platform = 'android'}) =>
      _repository.register(token, platform: platform);
}
