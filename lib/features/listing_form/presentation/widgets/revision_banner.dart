import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 031 (WS-B) — the stay-live edit notice shown at the top of the form
/// when [ListingFormState.isRevision] is true. Tells the publisher their edit
/// re-enters moderation and the LIVE listing stays unchanged until approved.
///
/// Token-clean (AppColors/AppTextStyles/AppSpacing/appRadius/EdgeInsetsDirectional).
class RevisionBanner extends StatelessWidget {
  const RevisionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: appRadius(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.published_with_changes,
            size: AppSpacing.lg,
            color: colors.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.revisionBannerTitle,
                  style: styles.labelLarge.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.revisionBannerBody,
                  style: styles.bodyMedium.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
