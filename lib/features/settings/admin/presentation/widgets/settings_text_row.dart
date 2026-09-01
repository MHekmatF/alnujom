// Phase 23 (spec/023-app-settings) — T016
// SettingsTextRow: a validated text field + Save button row.
// Used for support_contact channels, terms_url, privacy_url, and bilingual
// maintenance messages.
// Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';

import '../../../../../../core/localization/app_strings.dart';
import '../../../../../../core/theme/spacing.dart';
import '../../../../../../core/theme/typography.dart';
import '../../../../../../core/widgets/app_button.dart';

/// A single-row validated text field with an inline Save button.
///
/// [label]         — localised field label.
/// [initialValue]  — the current persisted value.
/// [isSaving]      — shows a spinner in place of the Save button while saving.
/// [onSave]        — called with the new value string; must return null on
///                   success or an error message string on failure.
/// [keyboardType]  — optional keyboard type (e.g. emailAddress, url).
/// [maxLines]      — optional maximum line count (default 1).
class SettingsTextRow extends StatefulWidget {
  const SettingsTextRow({
    super.key,
    required this.label,
    required this.initialValue,
    required this.isSaving,
    required this.onSave,
    this.keyboardType,
    this.maxLines = 1,
    this.saveLabel,
  });

  final String label;
  final String initialValue;
  final bool isSaving;
  final Future<String?> Function(String) onSave;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? saveLabel;

  @override
  State<SettingsTextRow> createState() => _SettingsTextRowState();
}

class _SettingsTextRowState extends State<SettingsTextRow> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(SettingsTextRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync if the persisted value changed from outside (e.g. after reload).
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text == oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    // Clear previous remote error on re-submit.
    setState(() => _errorText = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final error = await widget.onSave(_controller.text.trim());
    if (error != null && mounted) {
      setState(() => _errorText = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyles.of(context);
    // Batch-2: the hardcoded `OutlineInputBorder()` overrode the DS input theme
    // (token fill + focus ring); the stock TextButton became the DS AppButton
    // text variant, which carries the 48dp target and press feedback and can
    // render its own inline spinner while saving.
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
      child: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _controller,
                enabled: !widget.isSaving,
                keyboardType: widget.keyboardType,
                maxLines: widget.maxLines,
                style: styles.bodyLarge,
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: styles.bodyMedium,
                  isDense: true,
                  errorText: _errorText,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: widget.saveLabel ?? AppStrings.of(context).loc.action_save,
              variant: AppButtonVariant.text,
              size: AppButtonSize.dense,
              loading: widget.isSaving,
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}
