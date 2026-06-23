import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../l10n/app_localizations.dart';

/// Phase 14 — hero search bar; tapping navigates to SearchPage (SC-011).
/// Phase 33 restyle — a clean 54px pill (surface fill, hairline outline, soft
/// shadow) with a leading search glyph and placeholder, plus a solid-primary
/// circular filter button at the trailing edge. The smart-assistant entry is
/// preserved alongside it.
class HeroSearchBar extends StatelessWidget {
  const HeroSearchBar({super.key});

  /// The pill / filter-button height — a comfortable, tappable bar.
  static const double _barHeight = 54;

  /// The trailing circular action buttons (filter + assistant).
  static const double _actionSize = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: appRadius(AppRadii.pill),
                border: Border.all(color: colors.outline),
                boxShadow: elevation.level1,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: appRadius(AppRadii.pill),
                child: InkWell(
                  borderRadius: appRadius(AppRadii.pill),
                  // Typing intent → open Search with the keyboard focused.
                  onTap: () => context.go('${AppRoutes.search}?focus=1'),
                  child: SizedBox(
                    height: _barHeight,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.lg,
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
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Solid-primary circular filter button.
          _RoundAction(
            size: _actionSize,
            background: colors.primary,
            foreground: colors.onPrimary,
            icon: Icons.tune,
            onTap: () => context.go(AppRoutes.search),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Phase 28 (WS-6) — smart search assistant entry point.
          Tooltip(
            message: l10n.assistantTitle,
            child: _RoundAction(
              size: _actionSize,
              background: colors.primaryContainer,
              foreground: colors.onPrimaryContainer,
              icon: LucideIcons.sparkles,
              onTap: () => context.push(AppRoutes.assistant),
            ),
          ),
        ],
      ),
    );
  }
}

/// A circular icon button used for the search bar's trailing actions.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.size,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onTap,
  });

  final double size;
  final Color background;
  final Color foreground;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: AppSpacing.xl, color: foreground),
        ),
      ),
    );
  }
}
