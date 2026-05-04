import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import 'app_text_field.dart';
import '_widget_support.dart';

class SearchField extends StatefulWidget {
  const SearchField({
    this.controller,
    this.hint = 'Search',
    this.loading = false,
    this.enabled = true,
    this.showFilterIcon = false,
    this.onChanged,
    this.onClear,
    this.onFilterPressed,
    super.key,
  });

  final TextEditingController? controller;
  final String hint;
  final bool loading;
  final bool enabled;
  final bool showFilterIcon;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onFilterPressed;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _internalController;

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController)?.removeListener(
        _handleTextChange,
      );
      _controller.addListener(_handleTextChange);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _internalController?.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    if (mounted) setState(() {});
  }

  void _handleClear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasText = _controller.text.isNotEmpty;
    return AppTextField(
      label: widget.hint,
      controller: _controller,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      prefix: widget.loading
          ? appInlineSpinner(context)
          : Icon(LucideIcons.search, color: colors.textMuted),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasText)
            IconButton(
              onPressed: widget.enabled ? _handleClear : null,
              icon: Icon(LucideIcons.x, color: colors.textMuted),
            ),
          if (widget.showFilterIcon)
            IconButton(
              onPressed: widget.enabled ? widget.onFilterPressed : null,
              icon: Icon(LucideIcons.sliders_horizontal, color: colors.primary),
            ),
        ],
      ),
    );
  }
}
