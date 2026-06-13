// lib/core/notifications/local_reminder_scheduler.dart
//
// Phase 029 (F1 / W1) — device-local follow-up reminder scheduler for the CRM.
//
// There is NO server scheduler (pg_cron is not installed), so CRM follow-up
// reminders are delivered by flutter_local_notifications on the device. This
// wraps the plugin + the timezone database so the feature code (the CRM
// reminders cubit + the launch reschedule hook) deals only in domain terms
// (reminder uuid + title + due time).
//
// Every call is best-effort + guarded: a notification platform failure (no
// google-services, denied permission, blocked plugin) must NEVER crash the app
// — it degrades to "no local reminder" silently (the reminder still lives in
// the DB and shows in the in-app "due today" banner).

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:injectable/injectable.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../logging/app_logger.dart';

@lazySingleton
class LocalReminderScheduler {
  LocalReminderScheduler(this._logger);

  final AppLogger _logger;

  static const String _channelId = 'crm_reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _tzReady = false;

  /// Initialises the plugin + the timezone database (idempotent). Safe to call
  /// repeatedly; never throws.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(initSettings);

      // Timezone DB — needed for tz.TZDateTime conversion in zonedSchedule.
      tz_data.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
        _tzReady = true;
      } catch (e) {
        // Fall back to whatever default the tz package picked (UTC) — still
        // functional, just less precise.
        _logger.warning(
          'Could not resolve device timezone; using tz default.',
          error: e,
          tag: 'CrmReminders',
        );
        _tzReady = true;
      }

      _initialized = true;
    } catch (e, st) {
      _logger.warning(
        'LocalReminderScheduler init failed; local reminders disabled.',
        error: e,
        stackTrace: st,
        tag: 'CrmReminders',
      );
    }
  }

  /// Requests the Android notification permission (Android 13+). Best-effort;
  /// returns false on any failure. Call before the first [schedule].
  Future<bool> requestPermission() async {
    await ensureInitialized();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } catch (e) {
      _logger.warning(
        'requestNotificationsPermission failed.',
        error: e,
        tag: 'CrmReminders',
      );
      return false;
    }
  }

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        _channelId,
        'CRM follow-up reminders',
        channelDescription: 'Follow-up reminders for leads in your pipeline.',
        importance: Importance.high,
        priority: Priority.high,
      );

  /// Schedules a single reminder notification at [due] (local time). A past
  /// [due] is skipped. Uses an inexact (battery-friendly, no exact-alarm
  /// permission) schedule.
  Future<void> schedule({
    required String reminderId,
    required String title,
    required DateTime due,
  }) async {
    await ensureInitialized();
    if (!_initialized || !_tzReady) return;
    try {
      final when = tz.TZDateTime.from(due.toLocal(), tz.local);
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) {
        // Past-due reminders are surfaced by the in-app banner, not scheduled.
        return;
      }
      await _plugin.zonedSchedule(
        _notificationId(reminderId),
        title,
        null,
        when,
        const NotificationDetails(android: _androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminderId,
      );
    } catch (e, st) {
      _logger.warning(
        'Failed to schedule local reminder.',
        error: e,
        stackTrace: st,
        tag: 'CrmReminders',
      );
    }
  }

  /// Cancels the scheduled notification for [reminderId]. Best-effort.
  Future<void> cancel(String reminderId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_notificationId(reminderId));
    } catch (e) {
      _logger.warning(
        'Failed to cancel local reminder.',
        error: e,
        tag: 'CrmReminders',
      );
    }
  }

  /// Rebuilds the scheduled set from the publisher's open future reminders:
  /// cancels everything previously scheduled by this app, then (re)schedules
  /// each future reminder (capped at 50 to stay within OS alarm budgets).
  Future<void> syncOpenReminders(
    List<({String id, String title, DateTime due})> reminders,
  ) async {
    await ensureInitialized();
    if (!_initialized || !_tzReady) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      _logger.warning(
        'Failed to clear scheduled reminders before sync.',
        error: e,
        tag: 'CrmReminders',
      );
    }

    final now = DateTime.now();
    final future = reminders.where((r) => r.due.isAfter(now)).take(50);
    for (final r in future) {
      await schedule(reminderId: r.id, title: r.title, due: r.due);
    }
  }

  /// A stable 31-bit positive notification id derived from the reminder uuid
  /// (the OS notification id must be an int; we hash the uuid string).
  static int _notificationId(String uuid) {
    // FNV-1a 32-bit, masked to 31 bits (positive int).
    var hash = 0x811c9dc5;
    for (var i = 0; i < uuid.length; i++) {
      hash ^= uuid.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
