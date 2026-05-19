import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final palette = AppColors.of(context);
    final (Color bg, Color fg) = switch (status) {
      ListingStatus.draft ||
      ListingStatus.paused =>
        (scheme.surfaceContainerHighest, scheme.onSurface),
      ListingStatus.pendingReview => (
        palette.warning.withValues(alpha: 0.15),
        palette.warning,
      ),
      ListingStatus.approved => (
        palette.success.withValues(alpha: 0.15),
        palette.success,
      ),
      ListingStatus.rejected =>
        (scheme.errorContainer, scheme.onErrorContainer),
      ListingStatus.sold ||
      ListingStatus.rented ||
      ListingStatus.expired ||
      ListingStatus.deleted =>
        (scheme.surfaceContainerHigh, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        labelFor(status, l10n),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
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
