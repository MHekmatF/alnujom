import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';

class RejectionReasonBlock extends StatelessWidget {
  const RejectionReasonBlock({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.error.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.rejectionReasonLabel,
            style: styles.labelMedium.copyWith(color: colors.error),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reason,
            style: styles.bodyMedium.copyWith(color: colors.onSurface),
          ),
        ],
      ),
    );
  }
}
