import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';

/// Phase 12 — Approve confirmation dialog.
/// Returns `true` on Confirm and `null`/`false` on Cancel.
/// Contract: `contracts/phase12-listing-preview-page.md` §Approve dialog.
class ApproveConfirmationDialog extends StatelessWidget {
  const ApproveConfirmationDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const ApproveConfirmationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.adminApproveDialogTitle),
      content: Text(l10n.adminApproveDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.adminApproveDialogCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.adminApproveDialogConfirm),
        ),
      ],
    );
  }
}
