import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'app_button.dart';
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
        : _EmptyStateIcon(
            icon: icon!,
            // DC: a tonal (blue) badge by default; a caller-supplied accent
            // keeps its own low-alpha tint for semantic empties.
            bg: iconColor == null
                ? colors.primaryContainer
                : iconColor!.withValues(alpha: 0.12),
            fg: iconColor ?? colors.onPrimaryContainer,
          );

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: StaggeredListItem(
          index: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (art != null) ...[art, const SizedBox(height: AppSpacing.lg)],
              Semantics(
                header: true,
                child: Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: styles.titleLarge,
                ),
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

/// A glyph in a soft tinted circle — the shared premium treatment for
/// empty/list surfaces. The whole [EmptyState] fades + slides in via
/// [StaggeredListItem], so the glyph itself stays static.
class _EmptyStateIcon extends StatelessWidget {
  const _EmptyStateIcon({
    required this.icon,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    // DC empty-state badge: an 88px circle with a 44px glyph.
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Icon(icon, color: fg, size: 44),
    );
  }
}
