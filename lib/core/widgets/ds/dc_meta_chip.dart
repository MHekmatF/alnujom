import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../_widget_support.dart';

/// DC "Blue Crown" meta / source chip (`AlNujom - Publisher.dc.html` CRM source
/// badge): a small surface2 chip with a leading icon + label — e.g. the lead
/// source (محادثة / استفسار / معاينة). [label] is pre-localized by the caller.
class DcMetaChip extends StatelessWidget {
  const DcMetaChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: appRadius(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.textMuted),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: styles.labelSmall.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
