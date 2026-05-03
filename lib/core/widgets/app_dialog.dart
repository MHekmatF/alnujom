import 'package:flutter/material.dart';

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
    this.cancelLabel = 'Cancel',
    this.variant = AppDialogVariant.confirm,
    super.key,
  });

  final String title;
  final String? message;
  final String actionLabel;
  final String cancelLabel;
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
          label: cancelLabel,
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
