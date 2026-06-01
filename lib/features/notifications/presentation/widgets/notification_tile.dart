// lib/features/notifications/presentation/widgets/notification_tile.dart
//
// Phase 22 PN (T030) — Read/unread-styled tile for one AppNotification.
// Uses Phase 2 tokens throughout; NO inline hex/font/padding literals.
// Direction-aware via EdgeInsetsDirectional.

import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/notification_type.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    required this.notification,
    required this.onTap,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textStyles = AppTextStyles.of(context);
    final l10n = AppStrings.of(context).loc;
    final isUnread = notification.isUnread;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? colors.primaryContainer.withAlpha(0x26) : null,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon
            Container(
              width: AppSpacing.xxl,
              height: AppSpacing.xxl,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnread
                    ? colors.primary.withAlpha(0x1A)
                    : colors.surfaceVariant,
              ),
              child: Icon(
                _iconForType(notification.type),
                size: AppSpacing.lg,
                color: isUnread ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Title + relative time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleForType(notification.type, l10n),
                    style: isUnread
                        ? textStyles.labelLarge
                        : textStyles.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _relativeTime(notification.createdAt, l10n),
                    style: textStyles.labelMedium,
                  ),
                ],
              ),
            ),
            // Unread dot
            if (isUnread)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.sm,
                  top: AppSpacing.xs,
                ),
                child: Container(
                  width: AppSpacing.sm,
                  height: AppSpacing.sm,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.accountApproved:
        return Icons.verified_outlined;
      case NotificationType.accountRejected:
        return Icons.cancel_outlined;
      case NotificationType.listingApproved:
        return Icons.home_outlined;
      case NotificationType.listingRejected:
        return Icons.home_repair_service_outlined;
      case NotificationType.inquiryReceived:
        return Icons.mail_outline;
      case NotificationType.agencyInvitation:
        return Icons.group_add_outlined;
    }
  }

  String _titleForType(NotificationType type, dynamic l10n) {
    switch (type) {
      case NotificationType.accountApproved:
        return l10n.notification_type_account_approved;
      case NotificationType.accountRejected:
        return l10n.notification_type_account_rejected;
      case NotificationType.listingApproved:
        return l10n.notification_type_listing_approved;
      case NotificationType.listingRejected:
        return l10n.notification_type_listing_rejected;
      case NotificationType.inquiryReceived:
        return l10n.notification_type_inquiry_received;
      case NotificationType.agencyInvitation:
        return l10n.notification_type_agency_invitation;
    }
  }

  String _relativeTime(DateTime createdAt, dynamic l10n) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return l10n.notification_time_just_now;
    if (diff.inMinutes < 60) {
      return l10n.notification_time_minutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return l10n.notification_time_hours(diff.inHours);
    }
    return l10n.notification_time_days(diff.inDays);
  }
}
