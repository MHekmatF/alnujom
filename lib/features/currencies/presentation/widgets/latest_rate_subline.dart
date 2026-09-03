import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    // Batch-2: the two Text nodes inherited the ambient DefaultTextStyle; they
    // now carry the DS body/muted tokens like every other card subline.
    final muted = styles.bodyMedium.copyWith(color: colors.textMuted);
    final rate = latestRate;
    if (rate == null) {
      return Text(l10n.rateNotSetHint, style: muted);
    }
    final amount = '${RateFormatter.format(rate, locale)} $targetCurrencyCode';
    return Text(
      l10n.latestRateLineTemplate(baseCurrency, amount),
      // "1 SYP = 0.00006 USD" is an equation, not a sentence. Left to the
      // ambient RTL it renders as "SYP = 0.00006 USD 1" — the leading 1 is
      // reordered to the far end, and an exchange rate that reads backwards is
      // one an admin can act on wrongly. Seen on the device, 2026-09-03. Same
      // idiom the price tag and the listing cards already use.
      textDirection: TextDirection.ltr,
      style: muted,
    );
  }
}
