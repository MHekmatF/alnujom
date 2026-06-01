// lib/core/messaging/push_messaging_service.dart
//
// Phase 22 (spec/022-notifications-realtime) — domain-pure push abstraction.
//
// Principle IX: NO SDK import here. The sole FCM import lives in
// `lib/features/notifications/data/datasources/fcm_push_messaging_service.dart`.
// Everything in `domain/` and `lib/core/messaging/` is provider-agnostic.

/// Value object carrying the notification type key and its associated params
/// from a push payload. Used by [PushMessagingService] streams and by the
/// app-level listener to route deep links.
class PushPayload {
  const PushPayload({required this.type, required this.params});

  /// Matches the `type` column in the `notifications` table
  /// (e.g. 'account_approved', 'listing_rejected').
  final String type;

  /// The associated UUIDs from the `params` jsonb column
  /// (e.g. `{'listing_id': 'some-uuid'}`).  No free-text PII (FR-004).
  final Map<String, String> params;

  @override
  String toString() => 'PushPayload(type: $type, params: $params)';
}

/// Provider-agnostic push messaging interface.
///
/// Implemented by:
///   - `FcmPushMessagingService`  — delegates to `firebase_messaging` (data layer only)
///   - `NoopPushMessagingService` — no-op; [isAvailable] returns false
///
/// Neither the domain nor any other `lib/core/` file imports `package:firebase_*`.
abstract interface class PushMessagingService {
  /// Returns `true` when the push provider is configured and available.
  /// Always `false` for [NoopPushMessagingService].
  Future<bool> isAvailable();

  /// Returns the current FCM registration token for this device, or `null`
  /// when push is unconfigured / permission denied.
  Future<String?> currentToken();

  /// Emits a new token whenever FCM rotates it.  The subscriber should
  /// re-register the new token via `register_notification_token` RPC.
  Stream<String> onTokenRefresh();

  /// Emits a [PushPayload] for each push received while the app is in the
  /// foreground.  The app-level listener refreshes the badge; no OS banner.
  Stream<PushPayload> onMessage();

  /// Emits a [PushPayload] when the user taps a push notification and the app
  /// is backgrounded (but not terminated).  Triggers deep-link navigation.
  Stream<PushPayload> onMessageOpenedApp();

  /// Returns the [PushPayload] that launched a cold-start (terminated app)
  /// when the user tapped a notification, or `null` if the app was opened
  /// normally.  Called once at startup.
  Future<PushPayload?> initialMessage();
}
