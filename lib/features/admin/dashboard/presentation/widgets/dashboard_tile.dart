// Phase 20 (spec/020-admin-dashboard) — T009
// DashboardTile: an enabled tile that navigates to its section's route.
// Phase 2 tokens only — no inline hex/font-size/padding literals (FR-017).
// RTL/LTR correct via Directionality-aware widgets.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/spacing.dart';

/// An enabled, navigable admin-dashboard grid tile.
class DashboardTile extends StatelessWidget {
  const DashboardTile({
    super.key,
    required this.icon,
    required this.label,
    required this.route,
    this.counter,
  });

  final IconData icon;
  final String label;
  final String route;

  /// The counter badge value; null means not permitted (omit badge entirely).
  /// 0 means permitted but nothing pending (render badge distinctly).
  final int? counter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isZero
            ? colorScheme.surfaceContainerHighest
            : colorScheme.error,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isZero
              ? colorScheme.onSurfaceVariant
              : colorScheme.onError,
        ),
      ),
    );
  }
}
