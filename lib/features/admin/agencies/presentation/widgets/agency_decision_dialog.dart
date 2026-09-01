// Phase 19 (spec/019-agencies) — T067
// AgencyDecisionDialog: presents the 4 moderation actions to the admin.
// - approve: single step, no reason needed.
// - reject: requires a reason (preset + optional detail).
// - suspend: requires destructive confirmation step (FR-010).
// - reinstate: single step.
// Returns [AgencyDecisionResult] via Navigator.pop on confirm; null on cancel.
// Constitution VI: design tokens. Constitution IX: zero Supabase imports.
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../l10n/app_localizations.dart';

// ─── Action enum ─────────────────────────────────────────────────────────────

enum AgencyDecisionAction { approve, reject, suspend, reinstate }

// ─── Result ──────────────────────────────────────────────────────────────────

class AgencyDecisionResult {
  const AgencyDecisionResult({
    required this.action,
    this.rejectPreset,
    this.rejectDetail,
    this.suspendReason,
  });

  final AgencyDecisionAction action;

  /// Set when [action] == [AgencyDecisionAction.reject].
  final String? rejectPreset;
  final String? rejectDetail;

  /// Set when [action] == [AgencyDecisionAction.suspend].
  final String? suspendReason;
}

// ─── Dialog ──────────────────────────────────────────────────────────────────

class AgencyDecisionDialog extends StatefulWidget {
  const AgencyDecisionDialog({super.key, required this.action});

  final AgencyDecisionAction action;

  /// Convenience launcher — opens a dialog for the given [action] and returns
  /// the [AgencyDecisionResult] on confirm, or null on cancel.
  static Future<AgencyDecisionResult?> show(
    BuildContext context,
    AgencyDecisionAction action,
  ) {
    return showDialog<AgencyDecisionResult>(
      context: context,
      builder: (_) => AgencyDecisionDialog(action: action),
    );
  }

  @override
  State<AgencyDecisionDialog> createState() => _AgencyDecisionDialogState();
}

class _AgencyDecisionDialogState extends State<AgencyDecisionDialog> {
  static const int _maxDetailLength = 500;

  /// Whether we are in the destructive-confirmation step (suspend only).
  bool _confirmingDestructive = false;

  // Reject fields
  final TextEditingController _rejectPresetController = TextEditingController();
  final TextEditingController _rejectDetailController = TextEditingController();

  // Suspend reason field
  final TextEditingController _suspendReasonController =
      TextEditingController();

  @override
  void dispose() {
    _rejectPresetController.dispose();
    _rejectDetailController.dispose();
    _suspendReasonController.dispose();
    super.dispose();
  }

  void _onCancel() => Navigator.of(context).pop();

  void _onConfirm() {
    final action = widget.action;
    switch (action) {
      case AgencyDecisionAction.approve:
      case AgencyDecisionAction.reinstate:
        Navigator.of(context).pop(AgencyDecisionResult(action: action));
      case AgencyDecisionAction.reject:
        final preset = _rejectPresetController.text.trim();
        if (preset.isEmpty) return; // guard — button is disabled if empty
        Navigator.of(context).pop(
          AgencyDecisionResult(
            action: action,
            rejectPreset: preset,
            rejectDetail: _rejectDetailController.text.trim().isEmpty
                ? null
                : _rejectDetailController.text.trim(),
          ),
        );
      case AgencyDecisionAction.suspend:
        // First click → enter confirmation step.
        if (!_confirmingDestructive) {
          setState(() => _confirmingDestructive = true);
        } else {
          Navigator.of(context).pop(
            AgencyDecisionResult(
              action: action,
              suspendReason: _suspendReasonController.text.trim().isEmpty
                  ? null
                  : _suspendReasonController.text.trim(),
            ),
          );
        }
    }
  }

  void _onBackFromConfirm() => setState(() => _confirmingDestructive = false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.action == AgencyDecisionAction.suspend &&
        _confirmingDestructive) {
      return _buildSuspendConfirmStep(l10n);
    }

    return _buildMainStep(l10n);
  }

  // ── Main step ────────────────────────────────────────────────────────────────
  // Kept as a hand-rolled AlertDialog: the confirm action is gated on the
  // reject preset, and the suspend flow swaps into a second confirmation
  // step — neither fits AppDialog's fixed action pair. Visuals mirror the
  // AppDialog idiom (token type, AppButton actions).

  Widget _buildMainStep(AppLocalizations l10n) {
    final styles = AppTextStyles.of(context);
    final action = widget.action;

    String title;
    switch (action) {
      case AgencyDecisionAction.approve:
        title = l10n.agency_action_approve;
      case AgencyDecisionAction.reject:
        title = l10n.agency_action_reject;
      case AgencyDecisionAction.suspend:
        title = l10n.agency_action_suspend;
      case AgencyDecisionAction.reinstate:
        title = l10n.agency_action_reinstate;
    }

    Widget? content;
    bool canConfirm = true;

    if (action == AgencyDecisionAction.reject) {
      canConfirm = _rejectPresetController.text.trim().isNotEmpty;
      content = SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.agency_reject_reason_label, style: styles.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            // Preset field (required)
            // Batch-2: the hardcoded `OutlineInputBorder()` on these three
            // fields overrode the DS inputDecorationTheme (token fill + focus
            // ring); dropping it restores them.
            TextField(
              controller: _rejectPresetController,
              maxLength: 200,
              style: styles.bodyLarge,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.agency_reject_reason_label,
              ),
              onChanged: (_) => setState(() {}),
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
            ),
            const SizedBox(height: AppSpacing.md),
            // Optional detail
            TextField(
              controller: _rejectDetailController,
              maxLines: 3,
              maxLength: _maxDetailLength,
              style: styles.bodyLarge,
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
      );
    } else if (action == AgencyDecisionAction.suspend) {
      content = SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.agency_suspend_confirm_body, style: styles.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _suspendReasonController,
              maxLines: 3,
              maxLength: _maxDetailLength,
              style: styles.bodyLarge,
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
      );
    }

    final bool isDestructive =
        action == AgencyDecisionAction.suspend ||
        action == AgencyDecisionAction.reject;

    return AlertDialog(
      title: Text(title, style: styles.titleLarge),
      content: content,
      actions: [
        AppButton(
          label: MaterialLocalizations.of(context).cancelButtonLabel,
          variant: AppButtonVariant.text,
          onPressed: _onCancel,
        ),
        AppButton(
          label: title,
          variant: isDestructive
              ? AppButtonVariant.destructive
              : AppButtonVariant.filledPrimary,
          onPressed: canConfirm ? _onConfirm : null,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  // ── Suspend confirmation step ─────────────────────────────────────────────────
  // "Cancel" returns to the main step (does not pop), so this stays a
  // hand-rolled AlertDialog styled like AppDialog's destructive variant.

  Widget _buildSuspendConfirmStep(AppLocalizations l10n) {
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
      title: Text(l10n.agency_suspend_confirm_title, style: styles.titleLarge),
      content: Text(l10n.agency_suspend_confirm_body, style: styles.bodyMedium),
      actions: [
        AppButton(
          label: MaterialLocalizations.of(context).cancelButtonLabel,
          variant: AppButtonVariant.text,
          onPressed: _onBackFromConfirm,
        ),
        AppButton(
          label: l10n.agency_action_suspend,
          variant: AppButtonVariant.destructive,
          onPressed: _onConfirm,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}
