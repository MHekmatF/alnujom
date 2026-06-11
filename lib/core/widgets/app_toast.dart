import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Semantic flavor of an [AppToast]. Drives the leading icon + its tint;
/// the toast surface itself stays the premium dark-neutral snackbar so all
/// variants read as one family.
enum AppToastVariant { success, error, info, warning }

/// Branded toast — the single app-wide replacement for raw
/// `ScaffoldMessenger.showSnackBar` call-sites (Phase 28).
///
/// Still a [SnackBar] under the hood (same queueing/behavior semantics —
/// retrofits are strictly presentational), but every message now carries a
/// semantic leading icon in a tinted circle on the theme's floating dark
/// pill. Errors linger slightly longer than confirmations.
abstract final class AppToast {
  static void show(
    BuildContext context,
    String message, {
    AppToastVariant variant = AppToastVariant.info,
    SnackBarAction? action,
    Duration? duration,
  }) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final theme = Theme.of(context).snackBarTheme;
    final tint = _tint(colors, variant);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration:
              duration ??
              (variant == AppToastVariant.error
                  ? const Duration(seconds: 4)
                  : const Duration(seconds: 3)),
          action: action,
          content: Row(
            children: [
              Container(
                width: AppSpacing.xl,
                height: AppSpacing.xl,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon(variant), color: tint, size: AppSpacing.lg),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style:
                      theme.contentTextStyle ??
                      styles.bodyMedium.copyWith(color: colors.onSecondary),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, variant: AppToastVariant.success);

  static void error(BuildContext context, String message) =>
      show(context, message, variant: AppToastVariant.error);

  static void info(BuildContext context, String message) =>
      show(context, message, variant: AppToastVariant.info);

  static void warning(BuildContext context, String message) =>
      show(context, message, variant: AppToastVariant.warning);

  static IconData _icon(AppToastVariant variant) => switch (variant) {
    AppToastVariant.success => LucideIcons.circle_check,
    AppToastVariant.error => LucideIcons.circle_alert,
    AppToastVariant.info => LucideIcons.info,
    AppToastVariant.warning => LucideIcons.triangle_alert,
  };

  static Color _tint(AppColors colors, AppToastVariant variant) =>
      switch (variant) {
        AppToastVariant.success => colors.success,
        AppToastVariant.error => colors.error,
        AppToastVariant.info => colors.accent,
        AppToastVariant.warning => colors.warning,
      };
}
