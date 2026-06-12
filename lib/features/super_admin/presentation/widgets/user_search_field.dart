import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class UserSearchField extends StatefulWidget {
  const UserSearchField({
    required this.onChanged,
    required this.hintText,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  State<UserSearchField> createState() => _UserSearchFieldState();
}

class _UserSearchFieldState extends State<UserSearchField> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(LucideIcons.search),
      ),
      onChanged: (value) {
        _timer?.cancel();
        _timer = Timer(
          const Duration(milliseconds: 300),
          () => widget.onChanged(value),
        );
      },
    );
  }
}
