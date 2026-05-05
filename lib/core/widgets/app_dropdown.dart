import 'package:flutter/material.dart';

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.label,
    required this.items,
    this.value,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final String label;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final String? errorText;
  final bool enabled;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(labelText: label, errorText: errorText),
    );
  }
}
