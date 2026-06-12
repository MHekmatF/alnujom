import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/widgets/app_dialog.dart';
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
    return AppDialog(
      title: l10n.adminApproveDialogTitle,
      message: l10n.adminApproveDialogBody,
      icon: LucideIcons.circle_check,
      actionLabel: l10n.adminApproveDialogConfirm,
      cancelLabel: l10n.adminApproveDialogCancel,
      onAction: () => Navigator.of(context).pop(true),
    );
  }
}
