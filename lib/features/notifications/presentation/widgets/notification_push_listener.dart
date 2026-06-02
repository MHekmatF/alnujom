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
      // Refresh the unread badge — it is a @lazySingleton, the live user-visible
      // indicator. The center page owns a BlocProvider-scoped NotificationsCubit
      // and reloads on open / pull-to-refresh, so we deliberately do NOT poke a
      // throwaway factory NotificationsCubit here (it would refresh nothing).
      getIt<NotificationBadgeCubit>().refresh();
      _showForegroundSnackbar(payload);
    });

    // Background tap: route via deep-link resolver. Defer to post-frame so the
    // navigation runs AFTER any resume-triggered redirect settles (FR-012/SC-002).
    _onOpenedSub = _push.onMessageOpenedApp().listen((payload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _routeFromPayload(payload);
      });
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

    // dispatch_push puts the row id in data['notification_id'] (FCM v1 data
    // payload), so the resolver can mark this exact row read on tap (SC-002).
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
