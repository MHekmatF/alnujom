// lib/features/favorites/presentation/widgets/favorites_empty_state.dart
//
// Phase 17 Sub-Phase F (T034) — Empty state for FavoritesPage.
// Phase polish (Impeccable) — now uses the shared EmptyState so it teaches the
// interface (guiding subtext + a "Browse listings" CTA) and stays visually
// consistent with every other empty state. Token-only.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';

/// Shown when the user has no favorited listings (FR-026 / SC-012): an
/// illustration, the headline, guiding subtext, and a CTA back to the feed.
class FavoritesEmptyState extends StatelessWidget {
  const FavoritesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return EmptyState(
      illustration: Icon(
        Icons.favorite_border,
        size: AppSpacing.xxxl * 2,
        color: scheme.onSurfaceVariant,
      ),
      headline: l10n.favorites_empty_state,
      body: l10n.favorites_empty_body,
      ctaLabel: l10n.action_browse_listings,
      onCtaPressed: () => context.go(AppRoutes.home),
    );
  }
}
