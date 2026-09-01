import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/search_field.dart';

/// Debounced user search input for the assign-role screen.
///
/// Batch-2 restyle: this was a bare Material [TextField] with a `hintText` and a
/// leading glyph — no clear affordance, and the only search input in the app not
/// using the DS [SearchField]. It now renders [SearchField] (token fill, focus
/// ring, floating label, clear button) while keeping the identical 300 ms
/// debounce before [onChanged] fires.
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
    return SearchField(
      hint: widget.hintText,
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
