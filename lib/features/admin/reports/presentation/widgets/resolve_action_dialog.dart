// Phase 18 (spec/018-reports-moderation) — T057
// ResolveActionDialog: presents the 4 moderation actions to the admin.
// Destructive actions (hide, mark_duplicate, delete) require an explicit
// confirmation step (FR-017). Dismiss returns immediately.
// Returns [ResolveActionResult] via Navigator.pop on confirm; null on cancel.
// Constitution VI: design tokens. Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/moderation_action_type.dart';

/// The result object returned when the admin confirms an action.
class ResolveActionResult {
  const ResolveActionResult({required this.action, this.note});

  final ModerationActionType action;
  final String? note;
}

class ResolveActionDialog extends StatefulWidget {
  const ResolveActionDialog({super.key});

  /// Opens the dialog and returns a [ResolveActionResult] on confirm, or null
  /// when the admin cancels.
  static Future<ResolveActionResult?> show(BuildContext context) {
    return showDialog<ResolveActionResult>(
      context: context,
      builder: (_) => const ResolveActionDialog(),
    );
  }

  @override
  State<ResolveActionDialog> createState() => _ResolveActionDialogState();
}

class _ResolveActionDialogState extends State<ResolveActionDialog> {
  static const int _maxNoteLength = 500;

  /// The action selected in the first step; null = no selection yet.
  ModerationActionType? _selectedAction;

  /// Whether we are in the confirmation step for a destructive action.
  bool _confirmingDestructive = false;

  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _actionLabel(AppLocalizations l10n, ModerationActionType a) {
    switch (a) {
      case ModerationActionType.dismiss:
        return l10n.resolve_action_dismiss;
      case ModerationActionType.hide:
        return l10n.resolve_action_hide;
      case ModerationActionType.markDuplicate:
        return l10n.resolve_action_mark_duplicate;
      case ModerationActionType.delete:
        return l10n.resolve_action_delete;
    }
  }

  void _onSelectAction(ModerationActionType action) {
    if (action.isListingAffecting) {
      // Destructive: enter the confirmation step.
      setState(() {
        _selectedAction = action;
        _confirmingDestructive = true;
      });
    } else {
      // Non-destructive (dismiss): return immediately.
      Navigator.of(context).pop(
        ResolveActionResult(
          action: action,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        ),
      );
    }
  }

  void _onConfirmDestructive() {
    Navigator.of(context).pop(
      ResolveActionResult(
        action: _selectedAction!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  void _onBackFromConfirm() {
    setState(() {
      _confirmingDestructive = false;
    });
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _confirmingDestructive
        ? _buildConfirmStep(l10n)
        : _buildActionStep(l10n);
  }

  // Step 1 — pick an action + optional note.
  Widget _buildActionStep(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.report_resolve_dialog_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<ModerationActionType>(
              groupValue: _selectedAction,
              onChanged: (v) => setState(() => _selectedAction = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final action in ModerationActionType.values)
                    RadioListTile<ModerationActionType>(
                      value: action,
                      title: Text(_actionLabel(l10n, action)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.report_note_field_hint,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: _maxNoteLength,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _onCancel, child: Text(l10n.report_cancel_button)),
        FilledButton(
          onPressed: _selectedAction != null
              ? () => _onSelectAction(_selectedAction!)
              : null,
          child: Text(l10n.report_resolve_button),
        ),
      ],
    );
  }

  // Step 2 — confirm destructive action.
  Widget _buildConfirmStep(AppLocalizations l10n) {
    return AlertDialog(
      title: Text(l10n.resolve_confirm_title),
      content: Text(l10n.resolve_confirm_body),
      actions: [
        TextButton(
          onPressed: _onBackFromConfirm,
          child: Text(l10n.report_cancel_button),
        ),
        FilledButton(
          onPressed: _onConfirmDestructive,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: Text(_actionLabel(l10n, _selectedAction!)),
        ),
      ],
    );
  }
}
