import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/rate_formatter.dart';

/// Renders a compact "1 {base} = {amount} {target}" line for the latest rate
/// of a (base, target) pair. Uses `RateFormatter` rather than `MoneyFormatter`
/// so that small inverse rates like `0.000063` don't collapse to `$0.00` when
/// the target currency has `displayDecimals=2` (e.g. USD).
class LatestRateSubline extends StatelessWidget {
  const LatestRateSubline({
    required this.baseCurrency,
    required this.targetCurrencyCode,
    required this.latestRate,
    required this.locale,
    super.key,
  });

  final String baseCurrency;
  final String targetCurrencyCode;
  final Decimal? latestRate;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rate = latestRate;
    if (rate == null) {
      return Text(l10n.rateNotSetHint);
    }
    final amount = '${RateFormatter.format(rate, locale)} $targetCurrencyCode';
    return Text(l10n.latestRateLineTemplate(baseCurrency, amount));
  }
}
