import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import 'app_text_field.dart';
import '_widget_support.dart';

class SearchField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasText = controller?.text.isNotEmpty ?? false;
    return AppTextField(
      label: hint,
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      prefix: loading
          ? appInlineSpinner(context)
          : Icon(LucideIcons.search, color: colors.textMuted),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasText)
            IconButton(
              onPressed: onClear,
              icon: Icon(LucideIcons.x, color: colors.textMuted),
            ),
          if (showFilterIcon)
            IconButton(
              onPressed: onFilterPressed,
              icon: Icon(LucideIcons.sliders_horizontal, color: colors.primary),
            ),
        ],
      ),
    );
  }
}
