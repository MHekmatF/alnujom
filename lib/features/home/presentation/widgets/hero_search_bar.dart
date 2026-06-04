import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 14 — hero search bar; tapping navigates to SearchPage (SC-011).
/// Phase 25 (Claude Design) — a recessed pill search field with a solid
/// primary filter button alongside it.
class HeroSearchBar extends StatelessWidget {
  const HeroSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: colors.surfaceVariant,
              borderRadius: appRadius(AppRadii.pill),
              child: InkWell(
                borderRadius: appRadius(AppRadii.pill),
                onTap: () => context.go(AppRoutes.search),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: colors.textMuted),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.home_search_bar_placeholder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.bodyLarge.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: colors.primary,
            borderRadius: appRadius(AppRadii.md),
            child: InkWell(
              borderRadius: appRadius(AppRadii.md),
              onTap: () => context.go(AppRoutes.search),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Icon(Icons.tune, color: colors.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
