// Phase 20 (spec/020-admin-dashboard) — T009
// DashboardTile: an enabled tile that navigates to its section's route.
// RTL/LTR correct via Directionality-aware widgets.
//
// NOTE (batch-2): the admin home now renders the shared `DcQuickLinkTile` /
// `AppDashboardTile`, so this widget currently has no call sites. It was left in
// place (removal is a code change, not a visual one) but restyled off raw
// Material `theme.textTheme` / `colorScheme` onto the DS tokens so it cannot
// re-enter the app carrying pre-DS visuals.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../shared/util/localized_numbers.dart';

/// An enabled, navigable admin-dashboard grid tile.
class DashboardTile extends StatelessWidget {
  const DashboardTile({
    super.key,
    required this.icon,
    required this.label,
    required this.route,
    this.counter,
    this.secondaryCounter,
    this.secondaryCounterLabel,
  });

  final IconData icon;
  final String label;
  final String route;

  /// The counter badge value; null means not permitted (omit badge entirely).
  /// 0 means permitted but nothing pending (render badge distinctly).
  final int? counter;

  /// Optional secondary, informational counter (e.g. active listings) rendered
  /// as a caption under the label. null = omit; 0 = render "0 <label>".
  /// Requires [secondaryCounterLabel] to be non-null to display.
  final int? secondaryCounter;
  final String? secondaryCounterLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    // Compose the (already-localized) secondary caption outside Text() so the
    // l10n-literals lint passes — the label itself is localized by the caller.
    final secondaryCaption =
        (secondaryCounter != null && secondaryCounterLabel != null)
        ? '${formatLocalizedNumber(secondaryCounter!, Localizations.localeOf(context))} $secondaryCounterLabel'
        : null;

    return AppSurface(
      radius: AppRadii.lg,
      onTap: () => context.push(route),
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: AppSpacing.xxl, color: colors.primary),
              if (counter != null)
                PositionedDirectional(
                  top: -AppSpacing.xs,
                  end: -AppSpacing.md,
                  child: _CounterBadge(count: counter!),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: styles.labelLarge,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (secondaryCaption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              secondaryCaption,
              style: styles.labelSmall.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _CounterBadge extends StatelessWidget {
  const _CounterBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final isZero = count == 0;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isZero ? colors.surfaceVariant : colors.error,
        borderRadius: appRadius(AppRadii.sm),
      ),
      child: Text(
        formatLocalizedNumber(count, Localizations.localeOf(context)),
        style: styles.labelSmall.copyWith(
          color: isZero ? colors.textMuted : colors.onError,
        ),
      ),
    );
  }
}
