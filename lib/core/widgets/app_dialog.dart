import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'app_button.dart';

enum AppDialogVariant { confirm, destructive }

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.message,
    this.content,
    this.icon,
    this.cancelLabel,
    this.variant = AppDialogVariant.confirm,
    super.key,
  });

  final String title;
  final String? message;

  /// Optional widget rendered under [message] — input fields, choice lists,
  /// or any custom body a confirm/input dialog needs.
  final Widget? content;

  /// Optional leading icon rendered in a tinted circle above the title —
  /// semantic color follows [variant] (destructive → error tint).
  final IconData? icon;
  final String actionLabel;
  // Null → the localized generic "Cancel" (Arabic-first; no English default).
  final String? cancelLabel;
  final AppDialogVariant variant;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);
    final accentColor = variant == AppDialogVariant.destructive
        ? colors.error
        : colors.primary;

    final bodyChildren = <Widget>[
      if (message != null) Text(message!, style: styles.bodyMedium),
      if (message != null && content != null)
        const SizedBox(height: AppSpacing.lg),
      if (content != null) content!,
    ];

    return AlertDialog(
      icon: icon == null
          ? null
          : Container(
              width: AppSpacing.xxxl,
              height: AppSpacing.xxxl,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: AppSpacing.xl),
            ),
      title: Text(title, style: styles.titleLarge),
      content: bodyChildren.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: bodyChildren,
            ),
      actions: [
        AppButton(
          label: cancelLabel ?? AppStrings.of(context).loc.actionCancel,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        AppButton(
          label: actionLabel,
          variant: variant == AppDialogVariant.destructive
              ? AppButtonVariant.destructive
              : AppButtonVariant.filledPrimary,
          onPressed: onAction,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}
