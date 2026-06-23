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
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../domain/entities/app_notification.dart';
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

  /// Flattens the newest-first notification list into a render list where each
  /// new calendar day is preceded by a muted date header. Localized day labels
  /// come from [MaterialLocalizations] (no new l10n keys).
  List<_Row> _buildRows(List<AppNotification> notifications) {
    final rows = <_Row>[];
    DateTime? currentDay;
    for (final n in notifications) {
      final local = n.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (currentDay == null || day != currentDay) {
        currentDay = day;
        rows.add(_DateHeaderRow(day));
      }
      rows.add(_NotificationRow(n));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context).loc;

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
              return const AppSpinner.page();

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
              // Flatten the list into day-grouped rows (a muted date header
              // before each new calendar day, then its notification tiles).
              final rows = _buildRows(state.notifications);
              return RefreshIndicator(
                onRefresh: () => context.read<NotificationsCubit>().load(),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: rows.length + (state.isPaginating ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= rows.length) {
                      return const Padding(
                        padding: EdgeInsetsDirectional.all(AppSpacing.lg),
                        child: AppSpinner(),
                      );
                    }
                    final row = rows[index];
                    return switch (row) {
                      _DateHeaderRow(:final day) => _DateHeader(day: day),
                      _NotificationRow(:final notification) => NotificationTile(
                        notification: notification,
                        onTap: () => NotificationDeepLinkResolver.resolve(
                          context: context,
                          notification: notification,
                          updateCubit: true,
                        ),
                      ),
                    };
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

/// A muted day header that introduces each calendar-day group in the list.
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    // Fully localized (ar/en) without new l10n keys.
    final label = MaterialLocalizations.of(context).formatFullDate(day);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        label,
        style: styles.labelMedium.copyWith(
          color: colors.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Render-row model — a flat list of day headers + notification rows so the
// grouped list keeps a single ListView (pagination + spinner sentinel intact).
// ---------------------------------------------------------------------------

sealed class _Row {
  const _Row();
}

class _DateHeaderRow extends _Row {
  const _DateHeaderRow(this.day);
  final DateTime day;
}

class _NotificationRow extends _Row {
  const _NotificationRow(this.notification);
  final AppNotification notification;
}
