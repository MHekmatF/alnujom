import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 25 uplift — a small pill marking a field as required. Token-clean
/// (error-container fill, pill radius) so it reads as a soft badge rather than
/// a loud alert.
class RequiredFieldChip extends StatelessWidget {
  const RequiredFieldChip({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.12),
        borderRadius: appRadius(AppRadii.pill),
      ),
      child: Text(
        l10n.requiredFieldChipLabel,
        style: styles.labelMedium.copyWith(color: colors.error),
      ),
    );
  }
}
