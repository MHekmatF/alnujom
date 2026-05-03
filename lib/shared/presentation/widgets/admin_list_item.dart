import 'package:flutter/material.dart';

import 'package:alnujom/core/theme/colors.dart';
import 'package:alnujom/core/theme/spacing.dart';
import 'package:alnujom/core/theme/typography.dart';
import 'package:alnujom/core/widgets/_widget_support.dart';

class AdminListItem extends StatelessWidget {
  const AdminListItem({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: styles.titleMedium),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
