// lib/features/favorites/presentation/widgets/favorites_empty_state.dart
//
// Phase 17 Sub-Phase F (T034) — Empty state for FavoritesPage.
// Phase 2 tokens only; no inline hex, font-size, or padding (FR-029).
import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// Centered illustration + localized message shown when the user has no
/// favorited listings (FR-026 / SC-012).
class FavoritesEmptyState extends StatelessWidget {
  const FavoritesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: AppSpacing.xxxl * 2,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.favorites_empty_state,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
