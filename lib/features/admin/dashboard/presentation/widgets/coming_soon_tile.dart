// Phase 20 (spec/020-admin-dashboard) — T009
// ComingSoonTile: disabled, non-navigating, permission-gated tile.
// Phase 2 tokens only — no inline hex/font-size/padding literals (FR-017).
import 'package:flutter/material.dart';

import '../../../../../core/theme/spacing.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: colorScheme.onSurface.withValues(alpha: 0.38),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              comingSoonLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
