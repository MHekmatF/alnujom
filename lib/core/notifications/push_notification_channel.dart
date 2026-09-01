// lib/core/notifications/push_notification_channel.dart
//
// Phase 22 (spec/022-notifications-realtime) §6 device-QA finding — "no heads-up
// banner".
//
// THE BUG: `AndroidManifest.xml` points FCM at
// `com.google.firebase.messaging.default_notification_channel_id` but the app
// NEVER created that channel. On Android 8.0+ every notification must belong to
// a channel, and the channel — not the message — owns the importance. With no
// channel, FCM logged "Notification Channel ... has not been created by the app.
// Default value will be used." and fell back to its own low/default-importance
// channel, so pushes landed silently in the shade instead of popping over the
// screen. `android: {priority: 'high'}` in dispatch_push cannot override that.
//
// THE FIX: create the channel at startup with `Importance.high`
// (= NotificationManager.IMPORTANCE_HIGH), sound + vibration on.
//
// WHY A NEW CHANNEL ID: an Android notification channel is IMMUTABLE once
// created — re-creating it with a different importance is a no-op, and even
// deleting + re-creating the SAME id restores the user's previous settings
// (the OS deliberately remembers deleted channels so apps cannot nag their way
// back to heads-up). Any device that already ran a build carrying the old id
// would therefore keep the silent channel forever. So the id is VERSION-SUFFIXED
// (`…_v2`) and the stale ids are deleted, which is the only way an existing
// install actually picks up the upgrade.
//
// If the channel's importance/sound ever has to change again, bump the suffix
// and push the previous id onto [_staleChannelIds] — do NOT edit [channelId]
// in place.
//
// Everything is best-effort + guarded: a notification-platform failure (no
// google-services, blocked plugin, non-Android host) must never crash or block
// startup.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

import '../logging/app_logger.dart';

@lazySingleton
class PushNotificationChannel {
  PushNotificationChannel(this._logger);

  final AppLogger _logger;

  static const String _tag = 'PushChannel';

  /// The FCM default notification channel id.
  ///
  /// MUST stay byte-identical to the
  /// `com.google.firebase.messaging.default_notification_channel_id` meta-data
  /// value in `android/app/src/main/AndroidManifest.xml`.
  static const String channelId = 'alnujom_notifications_v2';

  /// Channel ids this app created (or caused to be created) in earlier
  /// versions. Deleted on first run of a build carrying a newer [channelId] so
  /// they stop cluttering the OS notification settings.
  ///
  ///  - `alnujom_notifications`        — the never-created / silent original.
  ///  - `fcm_fallback_notification_channel` — auto-created by the FCM SDK at
  ///    default importance precisely BECAUSE the original was missing; now that
  ///    a real default channel exists the SDK will not use it again.
  static const List<String> _staleChannelIds = <String>[
    'alnujom_notifications',
    'fcm_fallback_notification_channel',
  ];

  /// Heads-up (IMPORTANCE_HIGH) channel: pops over the current screen, makes a
  /// sound and vibrates. Name + description are the OS-settings labels; they are
  /// read by the Android system UI (not by the app's widget tree), are fixed at
  /// channel-creation time and cannot be re-localized afterwards, so they stay
  /// in the app's neutral English form — same convention as the Phase-29 CRM
  /// reminder channel in `local_reminder_scheduler.dart`.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    'Al Nujom notifications',
    description: 'Account, listing, inquiry and agency updates from Al Nujom.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ensured = false;

  /// Deletes the stale channels and (re)creates the current one. Idempotent —
  /// safe to call repeatedly; never throws. No-op off Android.
  Future<void> ensureCreated() async {
    if (_ensured) return;
    // Set first: a failure below is permanent for this process (the plugin is
    // unavailable), so retrying on every call would only re-log the same
    // warning.
    _ensured = true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return; // Not Android — nothing to create.

      for (final staleId in _staleChannelIds) {
        await android.deleteNotificationChannel(staleId);
      }
      await android.createNotificationChannel(_channel);
    } catch (e, st) {
      _logger.warning(
        'Could not create the push notification channel; '
        'pushes may arrive without a heads-up banner.',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
    }
  }
}
