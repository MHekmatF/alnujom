import 'package:flutter/material.dart';

import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/app_localizations.dart';

Future<bool> showDeleteConfirmationDialog(
  BuildContext context, {
  required String title,
  Future<({int cities, int areas})>? governorateDependsFuture,
  Future<int>? cityDependsFuture,
  String? customMessage,
}) async {
  final l10n = AppLocalizations.of(context)!;

  String message;
  if (governorateDependsFuture != null) {
    final deps = await governorateDependsFuture;
    message = l10n.deleteConfirmGovernorateWithDeps(deps.cities, deps.areas);
  } else if (cityDependsFuture != null) {
    final areaCount = await cityDependsFuture;
    message = l10n.deleteConfirmCityWithDeps(areaCount);
  } else {
    message = customMessage ?? title;
  }

  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      title: title,
      message: message,
      actionLabel: l10n.deleteAffordance,
      cancelLabel: l10n.actionCancel,
      variant: AppDialogVariant.destructive,
      onAction: () => Navigator.of(context).pop(true),
    ),
  );
  return result ?? false;
}
