import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../features/currencies/domain/entities/currency.dart';
import '../../../../features/listing_form/domain/entities/listing_price.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../domain/value_objects/money.dart';
import '../../money_formatter.dart';

/// Phase 12 Q8=A shared widget — primary price prominently, secondary prices
/// below. Phase 9 `MoneyFormatter` handles the locale-aware rendering
/// (Arabic-Indic digits + RTL bidi).
///
/// Constitution IX-clean: no Supabase imports. Accepts domain entities only.
class ListingPriceBlock extends StatelessWidget {
  const ListingPriceBlock({
    super.key,
    required this.prices,
    required this.displayCurrency,
    this.currenciesByCode = const <String, Currency>{},
  });

  final List<ListingPrice> prices;
  final Currency displayCurrency;

  /// Map for resolving secondary prices' currencies. If a secondary price's
  /// currency code is missing from the map, the secondary line is skipped
  /// (defensive — avoids rendering a stub like "5000 ???").
  final Map<String, Currency> currenciesByCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    if (prices.isEmpty) {
      return const SizedBox.shrink();
    }

    // Pick the primary price; fallback to the first row if none flagged.
    ListingPrice? primary;
    final secondaries = <ListingPrice>[];
    for (final p in prices) {
      if (primary == null && p.isPrimary) {
        primary = p;
      } else {
        secondaries.add(p);
      }
    }
    primary ??= prices.first;

    // The primary price renders in the displayCurrency.
    final primaryMoney = Money(
      amount: primary.amount,
      currencyCode: displayCurrency.code,
    );
    final primaryStr = MoneyFormatter.format(
      primaryMoney,
      locale: locale,
      currency: displayCurrency,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primaryStr,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final s in secondaries) ...[
          const SizedBox(height: AppSpacing.xs),
          Builder(
            builder: (ctx) {
              final currency = currenciesByCode[s.currencyCode];
              if (currency == null) return const SizedBox.shrink();
              final str = MoneyFormatter.format(
                Money(amount: s.amount, currencyCode: s.currencyCode),
                locale: locale,
                currency: currency,
              );
              return Text(
                l10n.priceOriginallyWas(str),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
