// lib/features/notifications/domain/usecases/deregister_push_token.dart
//
// Phase 22 — Use case: deregister this device's FCM token on logout (R-191).
// Per-device only — does NOT remove tokens for the user's other devices (SC-011).

import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../repositories/push_token_repository.dart';

@injectable
class DeregisterPushToken {
  const DeregisterPushToken(this._repository);

  final PushTokenRepository _repository;

  Future<Result<void>> call(String token) => _repository.deregister(token);
}
