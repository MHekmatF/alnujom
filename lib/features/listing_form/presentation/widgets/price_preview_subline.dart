import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../currencies/domain/entities/currency.dart';
import '../../../../shared/domain/value_objects/money.dart';
import '../../../../shared/presentation/money_formatter.dart';

class PricePreviewSubline extends StatelessWidget {
  const PricePreviewSubline({
    super.key,
    required this.amount,
    required this.currency,
  });

  final Decimal amount;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final money = Money(amount: amount, currencyCode: currency.code);
    final formatted = MoneyFormatter.format(
      money,
      locale: locale,
      currency: currency,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${l10n.pricePreviewLabel}: ',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          formatted,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
