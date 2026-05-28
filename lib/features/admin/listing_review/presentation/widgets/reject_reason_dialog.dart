import 'package:flutter/material.dart';

import '../../../../../core/listing/rejection_reason.dart';
import '../../../../../core/theme/spacing.dart';
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
    final theme = Theme.of(context);
    final detailLabel = _isOtherSelected
        ? l10n.rejectDialogDetailLabelRequired
        : l10n.rejectDialogDetailLabelOptional;
    final detailHint = _isOtherSelected
        ? l10n.rejectDialogDetailHintOther
        : null;
    final detailLength = _detailController.text.length;

    return AlertDialog(
      title: Text(l10n.rejectDialogTitle),
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
            Text(detailLabel, style: theme.textTheme.labelLarge),
            if (detailHint != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                detailHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _onCancel, child: Text(l10n.rejectDialogCancel)),
        FilledButton(
          onPressed: _isConfirmEnabled ? _onConfirm : null,
          child: Text(l10n.rejectDialogConfirm),
        ),
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
