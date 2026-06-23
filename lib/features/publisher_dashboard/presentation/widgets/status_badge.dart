import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';

/// Color-coded label for a listing's current status. Color mapping per
/// `contracts/my-listings-page.md § Listing card`:
///
/// - draft / paused → neutral
/// - pending_review → warning
/// - approved → success
/// - rejected → danger (theme.error)
/// - sold / rented / expired → muted (onSurfaceVariant)
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ListingStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    // Phase 33 — soft-tinted DS pill: one token tint drives both a low-alpha
    // background and the ink, with a hairline tint border. draft/paused stay
    // neutral (muted ink on the card-tone surface).
    final Color tint = switch (status) {
      ListingStatus.draft || ListingStatus.paused => palette.textMuted,
      ListingStatus.pendingReview => palette.warning,
      ListingStatus.approved => palette.success,
      ListingStatus.rejected => palette.error,
      ListingStatus.sold ||
      ListingStatus.rented ||
      ListingStatus.expired ||
      ListingStatus.deleted => palette.textMuted,
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: appRadius(AppRadii.pill),
        border: Border.all(color: tint.withValues(alpha: 0.30)),
      ),
      child: Text(
        labelFor(status, l10n),
        style: styles.labelMedium.copyWith(color: tint),
      ),
    );
  }

  static String labelFor(ListingStatus status, AppLocalizations l10n) {
    switch (status) {
      case ListingStatus.draft:
        return l10n.statusBadgeDraft;
      case ListingStatus.pendingReview:
        return l10n.statusBadgePendingReview;
      case ListingStatus.approved:
        return l10n.statusBadgeApproved;
      case ListingStatus.rejected:
        return l10n.statusBadgeRejected;
      case ListingStatus.paused:
        return l10n.statusBadgePaused;
      case ListingStatus.sold:
        return l10n.statusBadgeSold;
      case ListingStatus.rented:
        return l10n.statusBadgeRented;
      case ListingStatus.expired:
        return l10n.statusBadgeExpired;
      case ListingStatus.deleted:
        return l10n.statusBadgeDeleted;
    }
  }
}
