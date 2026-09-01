// Phase 20 (spec/020-admin-dashboard) — T009
// ComingSoonTile: disabled, non-navigating, permission-gated tile.
//
// NOTE (batch-2): like its sibling `dashboard_tile.dart`, this widget currently
// has no call sites (the admin home renders `DcQuickLinkTile`). Kept in place —
// removal is a code change, not a visual one — but restyled off raw Material
// `theme.textTheme` / `colorScheme` onto the DS tokens.
import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';

/// A disabled coming-soon tile shown for Ads and Settings sections.
/// Non-navigating — no onTap; visually de-emphasized.
class ComingSoonTile extends StatelessWidget {
  const ComingSoonTile({
    super.key,
    required this.icon,
    required this.label,
    required this.comingSoonLabel,
  });

  final IconData icon;
  final String label;
  final String comingSoonLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    // The old 38%-alpha onSurface wash failed AA in both themes; `textMuted` is
    // the DS token for de-emphasized copy and passes at 5.06:1 in light.
    return AppSurface(
      radius: AppRadii.lg,
      color: colors.surfaceVariant,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: AppSpacing.xxl, color: colors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: styles.labelLarge.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            comingSoonLabel,
            style: styles.labelSmall.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
