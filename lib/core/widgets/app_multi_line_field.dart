import 'package:flutter/material.dart';

import 'app_text_field.dart';

class AppMultiLineField extends StatefulWidget {
  const AppMultiLineField({required this.label, this.maxLength, super.key});

  final String label;
  final int? maxLength;

  @override
  State<AppMultiLineField> createState() => _AppMultiLineFieldState();
}

class _AppMultiLineFieldState extends State<AppMultiLineField> {
  var _count = 0;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      maxLines: null,
      helperText: widget.maxLength == null
          ? null
          : '$_count/${widget.maxLength}',
      onChanged: (value) => setState(() => _count = value.characters.length),
    );
  }
}
