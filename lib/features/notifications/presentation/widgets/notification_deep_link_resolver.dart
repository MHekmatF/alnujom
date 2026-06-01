// lib/features/notifications/presentation/widgets/notification_deep_link_resolver.dart
//
// Phase 22 PN (T031) — Maps NotificationType + params to pre-existing routes
// and marks the notification read on navigation.  Graceful "content
// unavailable" fallback for unresolved targets (FR-007/FR-018).
//
// Route constants sourced from AppRoutes (no hard-coded strings — token rule).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/routing/app_router.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/notification_type.dart';
import '../../domain/usecases/mark_notification_read.dart';
import '../bloc/notification_badge_cubit.dart';
import '../bloc/notifications_cubit.dart';

/// Resolves a notification to a route and navigates to it, marking it read.
///
/// Call [resolve] from the center page (tap) or the push listener (tap from
/// push).  Both paths use this same resolver so they cannot diverge (FR-012).
abstract final class NotificationDeepLinkResolver {
  /// Navigates to the notification's target route.
  ///
  /// - Marks the notification read (optimistic for in-app, fire-and-forget for
  ///   push-tap where the cubit may not be live).
  /// - Falls back to a "content unavailable" snackbar when the route cannot
  ///   be resolved (deleted listing, missing inquiry, etc.).
  static Future<void> resolve({
    required BuildContext context,
    required AppNotification notification,
    /// When `true` the method also calls NotificationsCubit.markRead so the
    /// center page reflects the change immediately (in-app tap).  When `false`
    /// (push-tap) we still fire the RPC but don't touch the cubit because the
    /// center may not be live.
    bool updateCubit = true,
  }) async {
    // Mark read via cubit (in-app tap) or directly via badge cubit.
    if (updateCubit) {
      try {
        unawaited(context.read<NotificationsCubit>().markRead(notification.id));
      } catch (_) {
        // Cubit not in scope (e.g. push-tap).
      }
    }
    // Always decrement the badge.
    if (notification.isUnread) {
      getIt<NotificationBadgeCubit>().decrement();
    }

    if (!context.mounted) return;

    final target = _resolveRoute(notification);
    if (target == null) {
      _showFallback(context);
      return;
    }

    switch (target) {
      case _NavRoute(:final path):
        context.go(path);
      case _NavNamedRoute(:final name, :final pathParams):
        context.goNamed(name, pathParameters: pathParams);
    }
  }

  /// Pure mapping (no navigation) — used by the push listener when context
  /// may be a non-Navigator context (e.g. cold-start routing).
  static void navigate({
    required BuildContext context,
    required String typeKey,
    required Map<String, String> params,
    required String notificationId,
    bool isUnread = true,
  }) {
    final type = NotificationType.fromKey(typeKey);
    if (type == null) {
      _showFallback(context);
      return;
    }
    // Push-tap path: no live center cubit, so mark the tapped row read directly
    // via the use case (fire-and-forget) so SC-002's "tap → marked read" holds
    // and the next badge fetch-on-resume reconciles to the correct count.
    if (notificationId.isNotEmpty) {
      unawaited(getIt<MarkNotificationRead>().call(notificationId));
    }
    // Decrement badge optimistically.
    if (isUnread) getIt<NotificationBadgeCubit>().decrement();

    final fakeNotification = AppNotification(
      id: notificationId,
      type: type,
      params: params,
      createdAt: DateTime.now(),
    );
    final target = _resolveRoute(fakeNotification);
    if (target == null) {
      _showFallback(context);
      return;
    }
    switch (target) {
      case _NavRoute(:final path):
        context.go(path);
      case _NavNamedRoute(:final name, :final pathParams):
        context.goNamed(name, pathParameters: pathParams);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static _NavTarget? _resolveRoute(AppNotification notification) {
    final params = notification.params;
    switch (notification.type) {
      case NotificationType.accountApproved:
        return const _NavRoute(AppRoutes.home);
      case NotificationType.accountRejected:
        return const _NavRoute(AppRoutes.rejected);
      case NotificationType.listingApproved:
        final id = params['listing_id'] as String?;
        if (id == null) return null;
        return _NavNamedRoute(
          AppRouteNames.listingDetails,
          pathParams: {'id': id},
        );
      case NotificationType.listingRejected:
        return const _NavRoute(AppRoutes.publisherMyListings);
      case NotificationType.inquiryReceived:
        return const _NavRoute(AppRoutes.inquiries);
      case NotificationType.agencyInvitation:
        return const _NavRoute(AppRoutes.agency);
    }
  }

  static void _showFallback(BuildContext context) {
    if (!context.mounted) return;
    final l10n = AppStrings.of(context).loc;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.notification_content_unavailable)),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sealed helper types for routing targets.
// ---------------------------------------------------------------------------

sealed class _NavTarget {
  const _NavTarget();
}

final class _NavRoute extends _NavTarget {
  const _NavRoute(this.path);
  final String path;
}

final class _NavNamedRoute extends _NavTarget {
  const _NavNamedRoute(this.name, {required this.pathParams});
  final String name;
  final Map<String, String> pathParams;
}
