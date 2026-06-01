// lib/features/notifications/presentation/widgets/notification_push_listener.dart
//
// Phase 22 PN (T036) — App-level push listener.
//
// Subscribes to the PD PushMessagingService streams (provider-agnostic — silent
// under the no-op adapter, FR-013):
//
//  • onMessageOpenedApp  — tap from background  → deep-link resolver (FR-012)
//  • initialMessage()   — cold-start tap        → resolver on first frame (FR-012/SC-002)
//  • onMessage          — foreground arrival     → badge refresh + optional snackbar;
//                                                 NO duplicate system banner (FR-014)
//
// Register this widget near the top of the widget tree (inside the router
// shell / app scaffold) so it is live app-wide.  Do NOT edit main.dart (PD owns it).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/messaging/push_messaging_service.dart';
import '../bloc/notification_badge_cubit.dart';
import '../bloc/notifications_cubit.dart';
import 'notification_deep_link_resolver.dart';

class NotificationPushListener extends StatefulWidget {
  const NotificationPushListener({required this.child, super.key});

  final Widget child;

  @override
  State<NotificationPushListener> createState() =>
      _NotificationPushListenerState();
}

class _NotificationPushListenerState extends State<NotificationPushListener> {
  late final PushMessagingService _push;
  StreamSubscription<PushPayload>? _onMessageSub;
  StreamSubscription<PushPayload>? _onOpenedSub;

  @override
  void initState() {
    super.initState();
    _push = getIt<PushMessagingService>();
    _subscribeStreams();
    _handleInitialMessage();
  }

  void _subscribeStreams() {
    // Foreground push: refresh badge + center, optional snackbar (FR-014).
    _onMessageSub = _push.onMessage().listen((payload) {
      getIt<NotificationBadgeCubit>().refresh();
      // Also refresh the center if it is currently mounted.
      try {
        getIt<NotificationsCubit>().refresh();
      } catch (_) {
        // Not registered / not open — safe to ignore.
      }
      _showForegroundSnackbar(payload);
    });

    // Background tap: route via deep-link resolver.
    _onOpenedSub = _push.onMessageOpenedApp().listen((payload) {
      if (mounted) _routeFromPayload(payload);
    });
  }

  void _handleInitialMessage() {
    // Cold-start: app was terminated, user tapped a push notification.
    _push.initialMessage().then((payload) {
      if (payload != null && mounted) {
        // Defer until after the first frame so the router is ready.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _routeFromPayload(payload);
        });
      }
    });
  }

  void _routeFromPayload(PushPayload payload) {
    if (!mounted) return;
    final type = payload.type;
    final params = payload.params;

    // We don't have a notification id from the push payload alone; the
    // resolver will still mark it read when the center loads via refresh.
    // Deep-link routing is the priority here.
    NotificationDeepLinkResolver.navigate(
      context: context,
      typeKey: type,
      params: params,
      notificationId: params['notification_id'] ?? '',
      isUnread: true,
    );
  }

  void _showForegroundSnackbar(PushPayload payload) {
    if (!mounted) return;
    final l10n = AppStrings.of(context).loc;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.notification_foreground_received),
        action: SnackBarAction(
          label: l10n.notification_foreground_view,
          onPressed: () {
            if (mounted) context.push('/notifications');
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _onMessageSub?.cancel();
    _onOpenedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
