// Phase 18 (spec/018-reports-moderation) — T057
// ResolveActionDialog: presents the 4 moderation actions to the admin.
// Destructive actions (hide, mark_duplicate, delete) require an explicit
// confirmation step (FR-017). Dismiss returns immediately.
// Returns [ResolveActionResult] via Navigator.pop on confirm; null on cancel.
// Constitution VI: design tokens. Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/app_button.dart';
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
  // Kept as a hand-rolled AlertDialog: the confirm action stays disabled
  // until an option is picked, and step 2's "cancel" goes back to step 1
  // instead of popping — neither fits AppDialog's fixed action pair.
  Widget _buildActionStep(AppLocalizations l10n) {
    final styles = AppTextStyles.of(context);
    return AlertDialog(
      title: Text(l10n.report_resolve_dialog_title, style: styles.titleLarge),
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
                      title: Text(
                        _actionLabel(l10n, action),
                        style: styles.bodyLarge,
                      ),
                      // Batch-2: DS type + token radio fill (was Material's
                      // ambient style / default primary).
                      activeColor: AppColors.of(context).primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.report_note_field_hint, style: styles.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: _maxNoteLength,
              style: styles.bodyLarge,
              // Batch-2: the hardcoded `OutlineInputBorder()` overrode the DS
              // inputDecorationTheme (token fill + focus ring).
              decoration: const InputDecoration(isDense: true),
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: l10n.report_cancel_button,
          variant: AppButtonVariant.text,
          onPressed: _onCancel,
        ),
        AppButton(
          label: l10n.report_resolve_button,
          onPressed: _selectedAction != null
              ? () => _onSelectAction(_selectedAction!)
              : null,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  // Step 2 — confirm destructive action. "Cancel" returns to step 1 (does
  // not pop), so this stays a hand-rolled AlertDialog styled like AppDialog's
  // destructive variant.
  Widget _buildConfirmStep(AppLocalizations l10n) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return AlertDialog(
      icon: Container(
        width: AppSpacing.xxxl,
        height: AppSpacing.xxxl,
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          LucideIcons.triangle_alert,
          color: colors.error,
          size: AppSpacing.xl,
        ),
      ),
      title: Text(l10n.resolve_confirm_title, style: styles.titleLarge),
      content: Text(l10n.resolve_confirm_body, style: styles.bodyMedium),
      actions: [
        AppButton(
          label: l10n.report_cancel_button,
          variant: AppButtonVariant.text,
          onPressed: _onBackFromConfirm,
        ),
        AppButton(
          label: _actionLabel(l10n, _selectedAction!),
          variant: AppButtonVariant.destructive,
          onPressed: _onConfirmDestructive,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}
