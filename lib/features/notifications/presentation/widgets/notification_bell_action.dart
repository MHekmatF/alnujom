// lib/features/notifications/presentation/widgets/notification_bell_action.dart
//
// Phase 22 PN (T033) — AppBar bell icon + unread-count badge.
// Driven by NotificationBadgeCubit (fetch-on-open/resume, not Realtime).
// Routes to /notifications on tap.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../bloc/notification_badge_cubit.dart';

class NotificationBellAction extends StatelessWidget {
  const NotificationBellAction({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context).loc;

    return BlocProvider.value(
      value: getIt<NotificationBadgeCubit>(),
      child: BlocBuilder<NotificationBadgeCubit, NotificationBadgeState>(
        builder: (context, state) {
          return IconButton(
            tooltip: l10n.notification_bell_tooltip,
            icon: _BellWithBadge(count: state.count),
            onPressed: () => context.push(AppRoutes.notifications),
          );
        },
      ),
    );
  }
}

class _BellWithBadge extends StatelessWidget {
  const _BellWithBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_outlined),
        if (count > 0)
          PositionedDirectional(
            top: -AppSpacing.xs,
            end: -AppSpacing.xs,
            child: _Badge(count: count),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      constraints: const BoxConstraints(
        minWidth: AppSpacing.lg,
        minHeight: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.error,
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onError,
          fontSize: 10,
        ),
      ),
    );
  }
}
