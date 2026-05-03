import 'package:flutter/material.dart';

import 'app_text_field.dart';

class AppNumberField extends StatelessWidget {
  const AppNumberField({
    required this.label,
    this.unit,
    this.unitPosition = TextDirection.rtl,
    this.onChanged,
    super.key,
  });

  final String label;
  final String? unit;
  final TextDirection unitPosition;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final unitWidget = unit == null ? null : Text(unit!);
    return AppTextField(
      label: label,
      keyboardType: TextInputType.number,
      prefix: unitPosition == TextDirection.ltr ? unitWidget : null,
      suffix: unitPosition == TextDirection.rtl ? unitWidget : null,
      onChanged: onChanged,
    );
  }
}
