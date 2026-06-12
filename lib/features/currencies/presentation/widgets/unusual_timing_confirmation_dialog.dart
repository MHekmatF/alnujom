import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/app_localizations.dart';

enum UnusualTimingDirection { future, backdate }

Future<bool> showUnusualTimingConfirmationDialog(
  BuildContext context, {
  required UnusualTimingDirection direction,
  required String magnitude,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      title: direction == UnusualTimingDirection.future
          ? l10n.unusualTimingFutureTitle
          : l10n.unusualTimingBackdateTitle,
      message: direction == UnusualTimingDirection.future
          ? l10n.unusualTimingFutureBody(magnitude)
          : l10n.unusualTimingBackdateBody(magnitude),
      icon: LucideIcons.clock,
      actionLabel: l10n.submitButton,
      cancelLabel: l10n.cancelButton,
      onAction: () => Navigator.of(context).pop(true),
    ),
  );
  return result ?? false;
}

String formatUnusualTimingMagnitude(Duration delta, AppLocalizations l10n) {
  final absDelta = delta.abs();
  final isFuture = !delta.isNegative;
  if (absDelta.inDays >= 1) {
    final days = absDelta.inDays;
    return isFuture
        ? l10n.unusualTimingFutureMagnitudeDays(days)
        : l10n.unusualTimingBackdateMagnitudeDays(days);
  }
  final hours = absDelta.inHours;
  return isFuture
      ? l10n.unusualTimingFutureMagnitudeHours(hours)
      : l10n.unusualTimingBackdateMagnitudeHours(hours);
}
