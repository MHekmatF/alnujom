import 'package:flutter/material.dart';

import '../../../../core/widgets/app_dialog.dart';

Future<bool?> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmButtonLabel,
  required String cancelButtonLabel,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      title: title,
      message: body,
      actionLabel: confirmButtonLabel,
      cancelLabel: cancelButtonLabel,
      variant: destructive
          ? AppDialogVariant.destructive
          : AppDialogVariant.confirm,
      onAction: () => Navigator.of(context).pop(true),
    ),
  );
}
