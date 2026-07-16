import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';

/// Phase 035 craft wave — THE one موثّق (field-verified) mark.
///
/// The audit found the verified state drawn four different ways
/// (LucideIcons.badge_check on green fill, bare badge_check, Material
/// Icons.verified, Icons.verified_outlined). Every surface now renders this
/// widget so the mark is a single recognizable stamp: green fill, white
/// badge-check, bold label (label hidden in [compact]).
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({this.compact = false, super.key});

  /// Icon-only variant for tight rows (compact card, chips).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.verified,
        borderRadius: appRadius(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.badge_check,
            size: AppSpacing.md,
            color: colors.onSuccess,
          ),
          if (!compact) ...[
            const SizedBox(width: AppSpacing.xxs),
            Text(
              l10n.detail_verified_badge,
              style: styles.labelMedium.copyWith(color: colors.onSuccess),
            ),
          ],
        ],
      ),
    );
  }
}
