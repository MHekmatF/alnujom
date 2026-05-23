import 'package:flutter/services.dart';

/// Phase 11 — thin Dart wrapper around the Kotlin MethodChannel that fires
/// the Android `ACTION_APPLICATION_DETAILS_SETTINGS` intent.
///
/// Used when the publisher denies the gallery permission (Q5=A flow) — the
/// picker surfaces an "Open settings" CTA that calls [openAppSettings] to
/// deep-link to the app's settings page so the publisher can grant the
/// permission without leaving the form.
///
/// No-op on non-Android platforms (Phase 11 is Android-only per
/// Constitution XI / Android-First MVP).
class AndroidSettingsChannel {
  static const _channel = MethodChannel('alnujom.app/android_settings');

  /// Fires the ACTION_APPLICATION_DETAILS_SETTINGS intent. Swallows
  /// PlatformException on platforms without the channel handler — the
  /// publisher can still navigate manually.
  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } on PlatformException {
      // Swallow — the deep-link is convenience, not correctness.
    } on MissingPluginException {
      // Platform doesn't implement the channel (non-Android or test env).
    }
  }
}
