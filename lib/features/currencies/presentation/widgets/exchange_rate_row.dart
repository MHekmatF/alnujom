import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exchange_rate.dart';
import 'derived_badge.dart';

class ExchangeRateRow extends StatelessWidget {
  const ExchangeRateRow({required this.exchangeRate, super.key});

  final ExchangeRate exchangeRate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final rateFormat = intl.NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = 6;
    final dateFormat = intl.DateFormat.yMMMd(locale).add_Hm();
    final source = exchangeRate.source?.trim().isEmpty == false
        ? exchangeRate.source!
        : l10n.unknownActorLabel;
    final setBy = exchangeRate.setByDisplayName ??
        (exchangeRate.setBy == null
            ? l10n.systemActorLabel
            : l10n.unknownActorLabel);

    return Card(
      child: ListTile(
        title: Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${exchangeRate.baseCurrency} → ${exchangeRate.targetCurrency}',
            ),
            if (exchangeRate.isDerived) const DerivedBadge(),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rateFormat.format(exchangeRate.rate.toDouble())),
            Text(
              '${l10n.effectiveAtLabel}: ${dateFormat.format(exchangeRate.effectiveAt.toLocal())}',
            ),
            Text('${l10n.setByLabel}: $setBy'),
            Text('${l10n.sourceLabel}: $source'),
          ],
        ),
      ),
    );
  }
}
