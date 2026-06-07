import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'app_button.dart';
import 'reduce_motion.dart';
import 'staggered_list_item.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.headline,
    this.body,
    this.illustration,
    this.icon,
    this.iconColor,
    this.ctaLabel,
    this.onCtaPressed,
    super.key,
  });

  final String headline;
  final String? body;

  /// A custom illustration (e.g. Lottie). Takes precedence over [icon].
  final Widget? illustration;

  /// Convenience: when [illustration] is null, this glyph is rendered in a soft
  /// tinted circle (premium default for the many list/empty surfaces).
  final IconData? icon;
  final Color? iconColor;

  final String? ctaLabel;
  final VoidCallback? onCtaPressed;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);

    Widget? art = illustration;
    art ??= icon == null
        ? null
        : _EmptyStateIcon(icon: icon!, color: iconColor ?? colors.primary);

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: StaggeredListItem(
          index: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (art != null) ...[art, const SizedBox(height: AppSpacing.lg)],
              Text(
                headline,
                textAlign: TextAlign.center,
                style: styles.titleLarge,
              ),
              if (body != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: styles.bodyMedium,
                ),
              ],
              if (ctaLabel != null && onCtaPressed != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(label: ctaLabel!, onPressed: onCtaPressed),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A glyph in a soft tinted circle with a one-shot scale-in pop (collapses to a
/// static icon under reduced motion). Shared premium treatment for empty/list
/// surfaces.
class _EmptyStateIcon extends StatelessWidget {
  const _EmptyStateIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: AppSpacing.xxxl + AppSpacing.lg,
      height: AppSpacing.xxxl + AppSpacing.lg,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.10),
      ),
      child: Icon(icon, color: color, size: AppSpacing.xxl),
    );
    if (reduceMotion(context)) return circle;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.7, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.emphasized,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: circle,
    );
  }
}
