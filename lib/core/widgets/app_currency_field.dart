import 'package:flutter/material.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<AppCurrency>(
          segments: const [
            ButtonSegment(value: AppCurrency.usd, label: Text('USD')),
            ButtonSegment(value: AppCurrency.syp, label: Text('SYP')),
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
          unit: _currency == AppCurrency.usd ? 'USD' : 'ل.س',
          onChanged: (value) {
            _amount = value;
            widget.onChanged?.call(value, _currency);
          },
        ),
      ],
    );
  }
}
