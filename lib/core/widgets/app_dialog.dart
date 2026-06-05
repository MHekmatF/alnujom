import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
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
    this.cancelLabel,
    this.variant = AppDialogVariant.confirm,
    super.key,
  });

  final String title;
  final String? message;
  final String actionLabel;
  // Null → the localized generic "Cancel" (Arabic-first; no English default).
  final String? cancelLabel;
  final AppDialogVariant variant;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    return AlertDialog(
      title: Text(title, style: styles.titleLarge),
      content: message == null
          ? null
          : Text(message!, style: styles.bodyMedium),
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
