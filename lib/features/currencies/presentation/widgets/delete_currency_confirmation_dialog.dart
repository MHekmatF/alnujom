import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/currency.dart';

Future<bool> showDeleteCurrencyConfirmationDialog(
  BuildContext context, {
  required Currency currency,
  required int exchangeRatesCount,
  required int listingPricesCount,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      title: l10n.deleteCurrencyConfirmTitle(currency.code),
      message: l10n.deleteCurrencyConfirmBody(
        exchangeRatesCount,
        listingPricesCount,
      ),
      icon: LucideIcons.triangle_alert,
      actionLabel: l10n.deleteButton,
      cancelLabel: l10n.cancelButton,
      variant: AppDialogVariant.destructive,
      onAction: () => Navigator.of(context).pop(true),
    ),
  );
  return result ?? false;
}
