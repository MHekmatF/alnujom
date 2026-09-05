import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../localization/app_strings.dart';
import 'app_text_field.dart';

class AppPasswordField extends StatefulWidget {
  const AppPasswordField({required this.label, this.onChanged, super.key});

  final String label;
  final ValueChanged<String>? onChanged;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context).loc;
    return AppTextField(
      label: widget.label,
      obscureText: _obscure,
      onChanged: widget.onChanged,
      suffix: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        // Plan A37 — the eye says what it does to a screen reader.
        tooltip: _obscure ? strings.a11yShowPassword : strings.a11yHidePassword,
        icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eye_off),
      ),
    );
  }
}
