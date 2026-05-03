import 'package:flutter/material.dart';

import 'app_text_field.dart';

class AppPhoneField extends StatefulWidget {
  const AppPhoneField({
    required this.label,
    this.countryCodes = const ['+963'],
    this.onChanged,
    super.key,
  });

  final String label;
  final List<String> countryCodes;
  final ValueChanged<String>? onChanged;

  @override
  State<AppPhoneField> createState() => _AppPhoneFieldState();
}

class _AppPhoneFieldState extends State<AppPhoneField> {
  late String _code;
  String _number = '';

  @override
  void initState() {
    super.initState();
    _code = widget.countryCodes.first;
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      keyboardType: TextInputType.phone,
      prefix: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _code,
          items: widget.countryCodes
              .map(
                (code) =>
                    DropdownMenuItem<String>(value: code, child: Text(code)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _code = value);
            widget.onChanged?.call('$_code$_number');
          },
        ),
      ),
      onChanged: (value) {
        _number = value;
        widget.onChanged?.call('$_code$value');
      },
    );
  }
}
