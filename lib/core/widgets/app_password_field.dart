import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

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
    return AppTextField(
      label: widget.label,
      obscureText: _obscure,
      onChanged: widget.onChanged,
      suffix: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eye_off),
      ),
    );
  }
}
