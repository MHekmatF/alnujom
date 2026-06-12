import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/listing/rejection_reason.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../l10n/app_localizations.dart';

/// Phase 12 (spec/012-listing-approval) — Reject-reason dialog (FR-013, Q3=A,
/// Q5=A). Returns a [RejectDialogResult] via `Navigator.pop` when Confirm is
/// tapped; returns `null` on Cancel or dismissal.
///
/// Q5=A enforcement (FR-013(d)): Confirm is enabled only when:
///   - a preset is selected, AND
///   - if preset == other, the detail field has a non-empty trimmed value.
///
/// Contract: `contracts/phase12-reject-reason-dialog.md`.
///
/// Kept as a hand-rolled [AlertDialog]: the confirm action stays disabled
/// until validation passes, which [AppDialog]'s fixed action pair cannot
/// express. Visuals mirror the AppDialog idiom (tinted destructive glyph,
/// token type, AppButton actions).
class RejectReasonDialog extends StatefulWidget {
  const RejectReasonDialog({super.key});

  /// Helper used by the preview page to open the dialog.
  static Future<RejectDialogResult?> show(BuildContext context) {
    return showDialog<RejectDialogResult>(
      context: context,
      builder: (_) => const RejectReasonDialog(),
    );
  }

  @override
  State<RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<RejectReasonDialog> {
  static const int _maxDetailLength = 500;

  RejectionReason? _selectedPreset;
  final TextEditingController _detailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _detailController.addListener(_onDetailChanged);
  }

  @override
  void dispose() {
    _detailController.removeListener(_onDetailChanged);
    _detailController.dispose();
    super.dispose();
  }

  void _onDetailChanged() {
    // Rebuild only — the trimmed-non-empty check depends on the live text.
    setState(() {});
  }

  bool get _isOtherSelected => _selectedPreset == RejectionReason.other;

  bool get _isConfirmEnabled {
    if (_selectedPreset == null) return false;
    if (_isOtherSelected) {
      return _detailController.text.trim().isNotEmpty;
    }
    return true;
  }

  String _presetLabel(AppLocalizations l10n, RejectionReason preset) {
    switch (preset) {
      case RejectionReason.missingOrLowQualityPhotos:
        return l10n.rejectPresetMissingOrLowQualityPhotos;
      case RejectionReason.incorrectLocation:
        return l10n.rejectPresetIncorrectLocation;
      case RejectionReason.unrealisticPrice:
        return l10n.rejectPresetUnrealisticPrice;
      case RejectionReason.incompleteDescription:
        return l10n.rejectPresetIncompleteDescription;
      case RejectionReason.duplicateListing:
        return l10n.rejectPresetDuplicateListing;
      case RejectionReason.other:
        return l10n.rejectPresetOther;
    }
  }

  void _onConfirm() {
    final trimmed = _detailController.text.trim();
    Navigator.of(context).pop(
      RejectDialogResult(
        preset: _selectedPreset!,
        detail: trimmed.isEmpty ? null : trimmed,
      ),
    );
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final detailLabel = _isOtherSelected
        ? l10n.rejectDialogDetailLabelRequired
        : l10n.rejectDialogDetailLabelOptional;
    final detailHint = _isOtherSelected
        ? l10n.rejectDialogDetailHintOther
        : null;
    final detailLength = _detailController.text.length;

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
      title: Text(l10n.rejectDialogTitle, style: styles.titleLarge),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Six presets, in enum order. Wrapped in RadioGroup per the
            // Flutter 3.32+ API (per-tile groupValue/onChanged are deprecated).
            RadioGroup<RejectionReason>(
              groupValue: _selectedPreset,
              onChanged: (v) => setState(() => _selectedPreset = v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final preset in RejectionReason.values)
                    RadioListTile<RejectionReason>(
                      value: preset,
                      title: Text(_presetLabel(l10n, preset)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(detailLabel, style: styles.labelLarge),
            if (detailHint != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                detailHint,
                style: styles.bodyMedium.copyWith(color: colors.textMuted),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _detailController,
              maxLines: 4,
              maxLength: _maxDetailLength,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              // Custom counter rendered below — suppress the built-in one.
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                l10n.rejectDialogCounter(detailLength),
                style: styles.bodyMedium.copyWith(color: colors.textMuted),
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: l10n.rejectDialogCancel,
          variant: AppButtonVariant.text,
          onPressed: _onCancel,
        ),
        AppButton(
          label: l10n.rejectDialogConfirm,
          variant: AppButtonVariant.destructive,
          onPressed: _isConfirmEnabled ? _onConfirm : null,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

/// Result returned via `Navigator.pop` when the admin taps Confirm.
class RejectDialogResult {
  const RejectDialogResult({required this.preset, this.detail});

  final RejectionReason preset;
  final String? detail;
}
