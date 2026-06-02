// lib/features/notifications/domain/entities/push_token.dart
//
// Phase 22 — Domain entity mirroring a row from `public.notification_tokens`.

/// Represents a device push token registered via `register_notification_token` RPC.
class PushToken {
  const PushToken({
    required this.token,
    required this.platform,
    required this.isActive,
    required this.lastSeenAt,
  });

  /// The FCM registration token string.
  final String token;

  /// Currently only 'android' is supported (Principle XI — Android-first).
  final String platform;

  /// Whether this token is still active (non-deregistered).
  final bool isActive;

  /// When this token was last confirmed active.
  final DateTime lastSeenAt;

  @override
  String toString() => 'PushToken(platform: $platform, isActive: $isActive)';
}
