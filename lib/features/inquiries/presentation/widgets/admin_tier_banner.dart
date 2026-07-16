// lib/features/inquiries/presentation/widgets/admin_tier_banner.dart
//
// Phase 16 Sub-Phase F (T068) — Banner rendered at the top of the admin
// inquiry oversight page to visually distinguish it from the publisher inbox.
// Restyled to the royal-blue DS: a soft primary-container strip with a
// hairline bottom outline. Token-only.
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../l10n/app_localizations.dart';

class AdminTierBanner extends StatelessWidget {
  const AdminTierBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        border: BorderDirectional(
          bottom: BorderSide(color: colors.outline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.shield_check,
              size: AppSpacing.lg,
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.admin_inquiries_tier_banner,
                style: styles.bodyMedium.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
