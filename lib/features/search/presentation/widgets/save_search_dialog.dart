// lib/features/search/presentation/widgets/save_search_dialog.dart
//
// Phase 25 premium uplift — prompts for a label before writing the current
// filters to `saved_searches`. Returns the trimmed label, or null if the user
// cancelled / left it blank.
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';

Future<String?> showSaveSearchDialog({
  required BuildContext context,
  String suggestedLabel = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _SaveSearchDialog(suggestedLabel: suggestedLabel),
  );
}

class _SaveSearchDialog extends StatefulWidget {
  const _SaveSearchDialog({required this.suggestedLabel});

  final String suggestedLabel;

  @override
  State<_SaveSearchDialog> createState() => _SaveSearchDialogState();
}

class _SaveSearchDialogState extends State<_SaveSearchDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.suggestedLabel);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _controller.text.trim();
    Navigator.of(context).pop(label.isEmpty ? null : label);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Branded AppDialog with the label field in its content slot. A blank
    // label pops null — identical to the old disabled-confirm outcome (the
    // caller treats null as "cancelled").
    return AppDialog(
      title: l10n.search_save_search_dialog_title,
      icon: LucideIcons.bookmark_plus,
      content: Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
        child: AppTextField(
          label: l10n.search_save_search_label_hint,
          controller: _controller,
          onChanged: (_) => setState(() {}),
        ),
      ),
      cancelLabel: l10n.search_save_search_cancel,
      actionLabel: l10n.search_save_search_confirm,
      onAction: _submit,
    );
  }
}
