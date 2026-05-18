import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/currency_with_latest_rates.dart';
import 'latest_rate_subline.dart';
import 'system_currency_badge.dart';

enum _CurrencyCardAction { edit, history, delete }

class CurrencyCard extends StatelessWidget {
  const CurrencyCard({
    required this.summary,
    required this.locale,
    required this.onEdit,
    required this.onViewHistory,
    this.onDelete,
    super.key,
  });

  final CurrencyWithLatestRates summary;
  final Locale locale;
  final VoidCallback onEdit;
  final VoidCallback onViewHistory;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currency = summary.currency;
    final latestRates = summary.latestRates.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: ListTile(
        leading: const Icon(Icons.currency_exchange),
        title: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${currency.code} · ${currency.localizedName(locale)}'),
            Text(currency.symbol),
            if (currency.isSystem) const SystemCurrencyBadge(),
            if (!currency.isActive) Chip(label: Text(l10n.hiddenBadge)),
          ],
        ),
        subtitle: latestRates.isEmpty
            ? Text(l10n.rateNotSetHint)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in latestRates)
                    LatestRateSubline(
                      baseCurrency: currency.code,
                      targetCurrencyCode: entry.key,
                      latestRate: entry.value,
                      locale: locale,
                    ),
                ],
              ),
        trailing: PopupMenuButton<_CurrencyCardAction>(
          onSelected: (action) => switch (action) {
            _CurrencyCardAction.edit => onEdit(),
            _CurrencyCardAction.history => onViewHistory(),
            _CurrencyCardAction.delete => onDelete?.call(),
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _CurrencyCardAction.edit,
              child: Text(l10n.editAffordance),
            ),
            PopupMenuItem(
              value: _CurrencyCardAction.history,
              child: Text(l10n.viewHistoryButton),
            ),
            if (onDelete != null)
              PopupMenuItem(
                value: _CurrencyCardAction.delete,
                child: Text(l10n.deleteButton),
              ),
          ],
        ),
        onTap: onViewHistory,
      ),
    );
  }
}
