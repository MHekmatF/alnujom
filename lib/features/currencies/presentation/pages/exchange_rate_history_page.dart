import 'package:flutter/material.dart';

import '../../../../core/widgets/locale_toggle_action.dart';
import '../../../../l10n/app_localizations.dart';

class ExchangeRateHistoryPage extends StatelessWidget {
  const ExchangeRateHistoryPage({required this.baseCurrencyCode, super.key});

  final String baseCurrencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exchangeRateHistoryPageTitle),
        actions: const [LocaleToggleAction()],
      ),
    );
  }
}
