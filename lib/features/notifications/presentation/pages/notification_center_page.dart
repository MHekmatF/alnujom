// lib/features/notifications/presentation/pages/notification_center_page.dart
//
// Phase 22 PN (T032) — Notification center: newest-first paginated list,
// unread styling, mark-all-read action, tap → resolver + MarkNotificationRead.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../bloc/notification_badge_cubit.dart';
import '../bloc/notifications_cubit.dart';
import '../widgets/notification_deep_link_resolver.dart';
import '../widgets/notification_tile.dart';

class NotificationCenterPage extends StatelessWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsCubit>(
      create: (_) => getIt<NotificationsCubit>()..load(),
      child: const _NotificationCenterView(),
    );
  }
}

class _NotificationCenterView extends StatefulWidget {
  const _NotificationCenterView();

  @override
  State<_NotificationCenterView> createState() =>
      _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<_NotificationCenterView> {
  late final ScrollController _scrollController;

  static const double _nextPageThreshold = 400;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _nextPageThreshold) {
      context.read<NotificationsCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context).loc;
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notification_center_title),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              final hasUnread = state.notifications.any((n) => n.isUnread);
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () {
                  context.read<NotificationsCubit>().markAllRead();
                  getIt<NotificationBadgeCubit>().clear();
                },
                child: Text(l10n.notification_mark_all_read),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          switch (state.status) {
            case NotificationsStatus.initial:
            case NotificationsStatus.loading:
              return const Center(child: CircularProgressIndicator());

            case NotificationsStatus.error:
              return ErrorState(
                title: l10n.notification_load_error,
                variant: ErrorStateVariant.network,
                onRetry: () => context.read<NotificationsCubit>().load(),
              );

            case NotificationsStatus.list:
              if (state.notifications.isEmpty) {
                return EmptyState(
                  icon: Icons.notifications_none_outlined,
                  headline: l10n.notification_empty_state,
                );
              }
              return RefreshIndicator(
                onRefresh: () => context.read<NotificationsCubit>().load(),
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount:
                      state.notifications.length + (state.isPaginating ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: colors.divider),
                  itemBuilder: (context, index) {
                    if (index >= state.notifications.length) {
                      return const Padding(
                        padding: EdgeInsetsDirectional.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final notification = state.notifications[index];
                    return NotificationTile(
                      notification: notification,
                      onTap: () => NotificationDeepLinkResolver.resolve(
                        context: context,
                        notification: notification,
                        updateCubit: true,
                      ),
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

