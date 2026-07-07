// lib/features/notifications/presentation/widgets/notification_tile.dart
//
// Phase 22 PN (T030) — Read/unread-styled tile for one AppNotification.
// Uses Phase 2 tokens throughout; NO inline hex/font/padding literals.
// Direction-aware via EdgeInsetsDirectional.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

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

    return Material(
      type: MaterialType.transparency,
      // Unread rows carry a subtle brand-blue wash so they read as "new" at a
      // glance; read rows stay on the page surface.
      color: isUnread ? colors.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          // Inset-free hairline restores rhythm between dense read rows.
          decoration: BoxDecoration(
            border: BorderDirectional(
              bottom: BorderSide(color: colors.divider),
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type icon in a soft neutral circle; the glyph carries a
                // semantic status color (success/error/brand) for triage.
                Container(
                  width: AppSpacing.xxl,
                  height: AppSpacing.xxl,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnread ? colors.surface : colors.surfaceVariant,
                  ),
                  child: Icon(
                    _iconForType(notification.type),
                    size: AppSpacing.lg,
                    color: _colorForType(colors, notification.type),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Title + optional body + relative time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleForType(notification.type, l10n),
                        // Bold title; unread is heavier still so it stands out.
                        style: textStyles.titleMedium.copyWith(
                          fontWeight: isUnread
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_bodyForType(
                            notification.type,
                            notification.params,
                            l10n,
                          )
                          case final body?) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          body,
                          style: textStyles.bodyMedium.copyWith(
                            color: colors.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _relativeTime(notification.createdAt, l10n),
                        style: textStyles.labelMedium.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Unread dot — announced to assistive tech as "unread".
                if (isUnread)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.sm,
                      top: AppSpacing.xs,
                    ),
                    child: Semantics(
                      label: l10n.notification_unread_a11y,
                      child: Container(
                        width: AppSpacing.sm,
                        height: AppSpacing.sm,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
      case NotificationType.savedSearchMatch:
        // Phase 25 — bell/search-style mark for a saved-search match alert.
        return LucideIcons.bell_ring;
    }
  }

  /// Semantic glyph color: approvals read success-green, rejections error-red,
  /// everything else stays brand-blue — so triage is possible at a glance.
  Color _colorForType(AppColors colors, NotificationType type) {
    switch (type) {
      case NotificationType.accountApproved:
      case NotificationType.listingApproved:
        return colors.success;
      case NotificationType.accountRejected:
      case NotificationType.listingRejected:
        return colors.error;
      case NotificationType.inquiryReceived:
      case NotificationType.agencyInvitation:
      case NotificationType.savedSearchMatch:
        return colors.primary;
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
      case NotificationType.savedSearchMatch:
        return l10n.notification_type_saved_search_match;
    }
  }

  /// Optional secondary line built from `params` for types that carry
  /// human-readable context. Returns `null` for types with no body so the
  /// tile stays single-line (matches existing behaviour).
  String? _bodyForType(
    NotificationType type,
    Map<String, dynamic> params,
    dynamic l10n,
  ) {
    switch (type) {
      case NotificationType.savedSearchMatch:
        // Phase 25 — built from the trigger's params (UUIDs + display labels).
        final listingTitle = params['listing_title'] as String?;
        final savedSearchLabel = params['saved_search_label'] as String?;
        if (listingTitle == null || savedSearchLabel == null) return null;
        return l10n.notification_body_saved_search_match(
          listingTitle,
          savedSearchLabel,
        );
      case NotificationType.accountApproved:
      case NotificationType.accountRejected:
      case NotificationType.listingApproved:
      case NotificationType.listingRejected:
      case NotificationType.inquiryReceived:
      case NotificationType.agencyInvitation:
        return null;
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
