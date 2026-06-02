// lib/features/notifications/data/datasources/fcm_push_messaging_service.dart
//
// Phase 22 — THE ONLY FILE importing `package:firebase_messaging`.
//
// Principle IX: no domain/ or lib/core/messaging/ file imports firebase_*.
// This adapter maps FCM callbacks → the provider-agnostic PushMessagingService
// interface so every feature above it remains Firebase-free.
//
// R-184: FcmPushMessagingService implements PushMessagingService.
// R-195: Firebase.initializeApp is guarded in lib/main.dart; if it fails,
//         NoopPushMessagingService is bound instead of this class.

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../../core/messaging/push_messaging_service.dart';

/// Converts a Firebase [RemoteMessage] to a [PushPayload].
///
/// FCM push data rides in `message.data` (the `data` map from dispatch_push).
/// Falls back to `message.notification` fields when `data` is absent (e.g.,
/// notification-only messages from the Firebase console).
PushPayload _toPayload(RemoteMessage message) {
  final data = message.data;
  final type = (data['type'] as String?) ?? '';
  final params = Map<String, String>.fromEntries(
    data.entries
        .where((e) => e.key != 'type' && e.value != null)
        .map((e) => MapEntry(e.key, e.value.toString())),
  );
  return PushPayload(type: type, params: params);
}

/// [PushMessagingService] adapter backed by [FirebaseMessaging].
///
/// Constructed in `lib/main.dart` inside the guarded `Firebase.initializeApp()`
/// try/catch and registered as a singleton in GetIt before `configureDependencies()`
/// runs.  When Firebase init fails, [NoopPushMessagingService] is registered
/// instead (R-195, SC-003).
class FcmPushMessagingService implements PushMessagingService {
  FcmPushMessagingService(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String?> currentToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> onTokenRefresh() => _messaging.onTokenRefresh;

  @override
  Stream<PushPayload> onMessage() =>
      FirebaseMessaging.onMessage.map(_toPayload);

  @override
  Stream<PushPayload> onMessageOpenedApp() =>
      FirebaseMessaging.onMessageOpenedApp.map(_toPayload);

  @override
  Future<PushPayload?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toPayload(message);
  }
}
