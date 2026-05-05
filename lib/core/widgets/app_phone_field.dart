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
  static const String _fallbackCode = '+';

  late String _code;
  String _number = '';

  List<String> get _effectiveCodes =>
      widget.countryCodes.isEmpty ? const [_fallbackCode] : widget.countryCodes;

  @override
  void initState() {
    super.initState();
    _code = _effectiveCodes.first;
  }

  @override
  void didUpdateWidget(covariant AppPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final codes = _effectiveCodes;
    if (!codes.contains(_code)) {
      setState(() => _code = codes.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final codes = _effectiveCodes;
    return AppTextField(
      label: widget.label,
      keyboardType: TextInputType.phone,
      prefix: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _code,
          items: codes
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
