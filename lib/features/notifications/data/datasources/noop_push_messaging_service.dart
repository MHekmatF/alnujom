// lib/features/notifications/data/datasources/noop_push_messaging_service.dart
//
// Phase 22 — No-op [PushMessagingService] bound when Firebase is absent or
// initialization fails (R-184, R-195, FR-013, SC-003).
//
// All methods return the "push unconfigured" safe defaults:
//   isAvailable()      → false
//   currentToken()     → null
//   onTokenRefresh()   → empty stream
//   onMessage()        → empty stream
//   onMessageOpenedApp()→ empty stream
//   initialMessage()   → null
//
// This keeps the app building and running when google-services.json is absent
// (the headline degraded-mode requirement SC-003/SC-010/FR-024).
// The in-app notification center, badge, and Realtime features all work normally.

import 'dart:async';

import '../../../../core/messaging/push_messaging_service.dart';

/// No-op implementation of [PushMessagingService].
///
/// Registered by the DI module when `Firebase.initializeApp` throws or when
/// `google-services.json` is absent from the build.
class NoopPushMessagingService implements PushMessagingService {
  const NoopPushMessagingService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String> onTokenRefresh() => const Stream.empty();

  @override
  Stream<PushPayload> onMessage() => const Stream.empty();

  @override
  Stream<PushPayload> onMessageOpenedApp() => const Stream.empty();

  @override
  Future<PushPayload?> initialMessage() async => null;
}
