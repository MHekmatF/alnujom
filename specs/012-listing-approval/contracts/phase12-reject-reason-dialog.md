# Contract: Reject-Reason Dialog (FR-013, Q3=A, Q5=A)

**Path**: `lib/features/admin/listing_review/presentation/widgets/reject_reason_dialog.dart`
**Implements**: FR-013, Q3=A (6 presets), Q5=A (Other-required UX gate)
**Verifies**: SC-012, SC-024, SC-028 (UX side)

## Widget contract

```dart
class RejectReasonDialog extends StatefulWidget {
  const RejectReasonDialog({super.key});
}

class RejectDialogResult {
  final RejectionReason preset;
  final String? detail;
}

// Returned via Navigator.pop(context, RejectDialogResult(...)) when Confirm tapped.
// Returned null when Cancel tapped or dialog dismissed.
```

## Layout

```text
┌──────────────────────────────────────────────────────┐
│ Reject this listing — please tell the publisher why │
├──────────────────────────────────────────────────────┤
│ ( ) Photos missing or low quality                   │
│ ( ) Location is incorrect or imprecise              │
│ ( ) Price appears unrealistic                       │
│ ( ) Description is incomplete or unclear            │
│ ( ) Duplicate of an existing listing                │
│ ( ) Other — please provide details                  │
│                                                     │
│ Additional details (optional)                       │
│ ┌─────────────────────────────────────────────────┐ │
│ │                                                 │ │
│ │                                                 │ │
│ └─────────────────────────────────────────────────┘ │
│ 0/500                                                │
│                                                     │
│  [ Cancel ]              [ Confirm (disabled) ]    │
└──────────────────────────────────────────────────────┘
```

## Confirm-button enable rule (Q5=A)

```dart
bool get _isConfirmEnabled {
  if (_selectedPreset == null) return false;
  if (_selectedPreset == RejectionReason.other) {
    return _detailController.text.trim().isNotEmpty;
  }
  return true;
}
```

## "Other" UX hint (FR-013(f))

When `_selectedPreset == RejectionReason.other`:
1. The text-field label flips from `admin.rejectDialog.detailLabel.optional` to `admin.rejectDialog.detailLabel.required`.
2. A localized hint appears above the field with key `admin.rejectDialog.detailHint.other`.

## Character cap

- TextField `maxLength: 500` (Flutter's built-in cap; the field rejects further input at 500 chars).
- Counter widget displays "{n}/500" via key `admin.rejectDialog.counter` with `{n}` as a placeholder.

## Six preset chips/radios

Rendered as a `Column` of `RadioListTile<RejectionReason>` widgets in the order from RejectionReason enum:

```dart
RadioListTile<RejectionReason>(
  value: RejectionReason.missingOrLowQualityPhotos,
  groupValue: _selectedPreset,
  onChanged: (v) => setState(() => _selectedPreset = v),
  title: Text(AppLocalizations.of(context)!.rejectPresetMissingOrLowQualityPhotos),
),
// ... 5 more for the other presets
```

## Confirm payload

```dart
void _onConfirm() {
  Navigator.pop(
    context,
    RejectDialogResult(
      preset: _selectedPreset!,
      detail: _detailController.text.trim().isEmpty ? null : _detailController.text.trim(),
    ),
  );
}
```

Note: empty trimmed string is serialized as `null` to the server, NOT as an empty string. The server's null-check (FR-002) is satisfied; the JSON-encoded reason has `detail: null` when the admin left the field empty for a non-Other preset.
