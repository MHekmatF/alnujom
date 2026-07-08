import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/gradients.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../l10n/app_localizations.dart';

/// Design #8 "Glass / Depth" — a frosted-glass search pill with a leading search
/// glyph + placeholder, an indigo-gradient filter button, and a glass smart-
/// assistant button. Tapping the pill opens Search with the keyboard focused.
class HeroSearchBar extends StatelessWidget {
  const HeroSearchBar({super.key});

  static const double _barHeight = 56;

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
            child: GlassPanel(
              radius: AppRadii.lg,
              blur: 14,
              tintOpacity: 0.80,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
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
          Tooltip(
            message: l10n.search_filters_button,
            child: _GradientAction(
              size: _barHeight,
              icon: Icons.tune,
              onTap: () => context.go(AppRoutes.search),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Tooltip(
            message: l10n.assistantTitle,
            child: _GlassAction(
              size: _barHeight,
              icon: LucideIcons.sparkles,
              onTap: () => context.push(AppRoutes.assistant),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded-square indigo-gradient action button (the filter entry).
class _GradientAction extends StatelessWidget {
  const _GradientAction({
    required this.size,
    required this.icon,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final gradients = AppGradients.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: appRadius(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradients.primaryGradient,
          borderRadius: appRadius(AppRadii.lg),
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: AppSpacing.xl, color: colors.onPrimary),
          ),
        ),
      ),
    );
  }
}

/// A rounded-square frosted-glass action button (the assistant entry).
class _GlassAction extends StatelessWidget {
  const _GlassAction({
    required this.size,
    required this.icon,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GlassPanel(
      radius: AppRadii.lg,
      blur: 14,
      tintOpacity: 0.80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: AppSpacing.xl, color: colors.primary),
          ),
        ),
      ),
    );
  }
}
