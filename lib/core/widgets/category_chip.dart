import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    required this.label,
    required this.icon,
    this.selected = false,
    this.enabled = true,
    this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final foreground = selected ? colors.onPrimary : colors.onSurface;
    return AppTapTarget(
      child: ActionChip(
        avatar: Icon(icon, color: foreground, size: AppSpacing.xl),
        label: Text(
          label,
          style: styles.labelLarge.copyWith(color: foreground),
        ),
        onPressed: enabled ? onPressed : null,
        backgroundColor: selected ? colors.primary : colors.card,
        disabledColor: colors.surfaceVariant,
        side: BorderSide(color: selected ? colors.primary : colors.outline),
        shape: RoundedRectangleBorder(borderRadius: appRadius(AppRadii.pill)),
      ),
    );
  }
}
