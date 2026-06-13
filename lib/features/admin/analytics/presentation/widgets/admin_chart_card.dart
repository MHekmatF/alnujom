// Phase 29 (029-crm-reels-growth) — W2: admin analytics chart card shell.
// A titled card wrapper for each admin chart. When [isEmpty] it renders a
// centered, muted empty hint instead of the chart body — so a partially-
// permissioned admin (whose RPC returned zero rows) sees a calm hint, never an
// error. Token-clean.
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/elevation.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';

class AdminChartCard extends StatelessWidget {
  const AdminChartCard({
    super.key,
    required this.title,
    required this.child,
    required this.isEmpty,
    required this.emptyHint,
  });

  final String title;
  final Widget child;
  final bool isEmpty;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: styles.titleMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isEmpty)
            _EmptyHint(hint: emptyHint)
          else
            child,
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.chart_no_axes_column,
              size: AppSpacing.xxl,
              color: colors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: styles.bodyMedium.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
