import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';
import 'dimens.dart';
import 'press_scale.dart';

enum AppButtonVariant {
  filledPrimary,
  filledSuccess,
  outlined,
  tonal,
  text,
  destructive,
  iconButton,
  fab,
}

enum AppButtonSize { regular, dense }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filledPrimary,
    this.size = AppButtonSize.regular,
    this.loading = false,
    this.icon,
    super.key,
  });

  const AppButton.filledPrimary({
    required String label,
    required VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.regular,
    bool loading = false,
    Key? key,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         size: size,
         loading: loading,
       );

  const AppButton.iconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    String label = '',
    bool loading = false,
    Key? key,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: AppButtonVariant.iconButton,
         icon: icon,
         loading: loading,
       );

  const AppButton.fab({
    required VoidCallback? onPressed,
    IconData icon = LucideIcons.plus,
    String label = '',
    bool loading = false,
    Key? key,
  }) : this(
         key: key,
         label: label,
         onPressed: onPressed,
         variant: AppButtonVariant.fab,
         icon: icon,
         loading: loading,
       );

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final visualHeight = size == AppButtonSize.dense
        ? AppDimens.buttonDenseHeight
        : AppSpacing.xxxl;
    final enabled = onPressed != null && !loading;

    // Consequential actions get a light haptic tick on tap.
    final usesHaptic =
        variant == AppButtonVariant.filledPrimary ||
        variant == AppButtonVariant.filledSuccess ||
        variant == AppButtonVariant.destructive ||
        variant == AppButtonVariant.fab;
    void handleTap() {
      if (usesHaptic) HapticFeedback.selectionClick();
      onPressed?.call();
    }

    final effectiveOnPressed = enabled ? handleTap : null;

    if (variant == AppButtonVariant.iconButton) {
      return AppTapTarget(
        child: IconButton(
          onPressed: effectiveOnPressed,
          icon: loading
              ? appInlineSpinner(context, color: colors.primary)
              : Icon(icon ?? LucideIcons.circle),
          color: colors.primary,
          tooltip: label.isEmpty ? null : label,
        ),
      );
    }

    if (variant == AppButtonVariant.fab) {
      return AppTapTarget(
        child: FloatingActionButton(
          onPressed: effectiveOnPressed,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          child: loading
              ? appInlineSpinner(context, color: colors.onPrimary)
              : Icon(icon ?? LucideIcons.plus),
        ),
      );
    }

    final foreground = _foreground(colors);
    final background = _background(colors);
    final border = variant == AppButtonVariant.outlined
        ? BorderSide(color: colors.outlineStrong)
        : BorderSide.none;
    final child = loading
        ? appInlineSpinner(context, color: foreground)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSpacing.xl),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label),
            ],
          );

    return PressScale(
      enabled: enabled,
      child: AppTapTarget(
        child: TextButton(
          onPressed: effectiveOnPressed,
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(
              Size(AppSpacing.xxxl, visualHeight),
            ),
            padding: WidgetStatePropertyAll(
              appPadding(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            ),
            backgroundColor: WidgetStatePropertyAll(background),
            foregroundColor: WidgetStatePropertyAll(foreground),
            textStyle: WidgetStatePropertyAll(styles.labelLarge),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: appRadius(AppRadii.md),
                side: border,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Color _foreground(AppColors colors) => switch (variant) {
    AppButtonVariant.filledPrimary => colors.onPrimary,
    AppButtonVariant.filledSuccess => colors.onSuccess,
    AppButtonVariant.outlined => colors.primary,
    AppButtonVariant.tonal => colors.onPrimaryContainer,
    AppButtonVariant.text => colors.primary,
    AppButtonVariant.destructive => colors.onError,
    AppButtonVariant.iconButton => colors.primary,
    AppButtonVariant.fab => colors.onPrimary,
  };

  Color _background(AppColors colors) => switch (variant) {
    AppButtonVariant.filledPrimary => colors.primary,
    AppButtonVariant.filledSuccess => colors.success,
    AppButtonVariant.outlined => Colors.transparent,
    AppButtonVariant.tonal => colors.primaryContainer,
    AppButtonVariant.text => Colors.transparent,
    AppButtonVariant.destructive => colors.error,
    AppButtonVariant.iconButton => Colors.transparent,
    AppButtonVariant.fab => colors.primary,
  };
}
