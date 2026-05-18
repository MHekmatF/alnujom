import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/rate_formatter.dart';
import '../../../../shared/util/arabic_digits.dart';
import '../../domain/entities/exchange_rate.dart';
import 'derived_badge.dart';

class ExchangeRateRow extends StatelessWidget {
  const ExchangeRateRow({required this.exchangeRate, super.key});

  final ExchangeRate exchangeRate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final dateFormat = intl.DateFormat.yMMMd(locale.toLanguageTag()).add_Hm();
    final source = exchangeRate.source?.trim().isEmpty == false
        ? exchangeRate.source!
        : l10n.unknownActorLabel;
    final displayName = exchangeRate.setByDisplayName?.trim();
    final setBy = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (exchangeRate.setBy == null
              ? l10n.systemActorLabel
              : l10n.unknownActorLabel);

    return Card(
      child: ListTile(
        title: Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.exchangeRatePairLabel(
                exchangeRate.baseCurrency,
                exchangeRate.targetCurrency,
              ),
            ),
            if (exchangeRate.isDerived) const DerivedBadge(),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(RateFormatter.format(exchangeRate.rate, locale)),
            Text(
              _localizeDate(locale, dateFormat, exchangeRate.effectiveAt, l10n),
            ),
            Text(l10n.setByLineFormat(setBy)),
            Text(l10n.sourceLineFormat(source)),
          ],
        ),
      ),
    );
  }

  String _localizeDate(
    Locale locale,
    intl.DateFormat dateFormat,
    DateTime ts,
    AppLocalizations l10n,
  ) {
    final raw = dateFormat.format(ts.toLocal());
    final localized = locale.languageCode == 'ar'
        ? toArabicIndicNumerals(raw)
        : raw;
    return '${l10n.effectiveAtLabel}: $localized';
  }
}
