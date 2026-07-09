// Phase 20 (spec/020-admin-dashboard) — T009
// DashboardTile: an enabled tile that navigates to its section's route.
// Phase 2 tokens only — no inline hex/font-size/padding literals (FR-017).
// RTL/LTR correct via Directionality-aware widgets.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/spacing.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Compose the (already-localized) secondary caption outside Text() so the
    // l10n-literals lint passes — the label itself is localized by the caller.
    final secondaryCaption =
        (secondaryCounter != null && secondaryCounterLabel != null)
        ? '${formatLocalizedNumber(secondaryCounter!, Localizations.localeOf(context))} $secondaryCounterLabel'
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 32, color: colorScheme.primary),
                  if (counter != null)
                    Positioned(
                      top: -AppSpacing.xs,
                      right: -AppSpacing.md,
                      child: _CounterBadge(count: counter!),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelLarge,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (secondaryCaption != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  secondaryCaption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterBadge extends StatelessWidget {
  const _CounterBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isZero = count == 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isZero ? colorScheme.surfaceContainerHighest : colorScheme.error,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        formatLocalizedNumber(count, Localizations.localeOf(context)),
        style: theme.textTheme.labelSmall?.copyWith(
          color: isZero ? colorScheme.onSurfaceVariant : colorScheme.onError,
        ),
      ),
    );
  }
}
