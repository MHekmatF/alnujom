import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/spacing.dart';
import 'app_number_field.dart';

enum AppCurrency { usd, syp }

class AppCurrencyField extends StatefulWidget {
  const AppCurrencyField({required this.label, this.onChanged, super.key});

  final String label;
  final void Function(String amount, AppCurrency currency)? onChanged;

  @override
  State<AppCurrencyField> createState() => _AppCurrencyFieldState();
}

class _AppCurrencyFieldState extends State<AppCurrencyField> {
  var _currency = AppCurrency.usd;
  var _amount = '';

  @override
  Widget build(BuildContext context) {
    final loc = AppStrings.of(context).loc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<AppCurrency>(
          segments: [
            ButtonSegment(
              value: AppCurrency.usd,
              label: Text(loc.currencyUsdName),
            ),
            ButtonSegment(
              value: AppCurrency.syp,
              label: Text(loc.currencySypName),
            ),
          ],
          selected: {_currency},
          onSelectionChanged: (selected) {
            setState(() => _currency = selected.first);
            widget.onChanged?.call(_amount, _currency);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        AppNumberField(
          label: widget.label,
          unit: _currency == AppCurrency.usd
              ? loc.currencyUsdSymbol
              : loc.currencySypSymbol,
          onChanged: (value) {
            _amount = value;
            widget.onChanged?.call(value, _currency);
          },
        ),
      ],
    );
  }
}
