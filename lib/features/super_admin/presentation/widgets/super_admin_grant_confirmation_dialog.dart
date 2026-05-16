import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/user_search_result.dart';

Future<String?> showSuperAdminGrantConfirmationDialog(
  BuildContext context, {
  required UserSearchResult targetUser,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _SuperAdminGrantConfirmationDialog(targetUser: targetUser),
  );
}

class _SuperAdminGrantConfirmationDialog extends StatefulWidget {
  const _SuperAdminGrantConfirmationDialog({required this.targetUser});

  final UserSearchResult targetUser;

  @override
  State<_SuperAdminGrantConfirmationDialog> createState() =>
      _SuperAdminGrantConfirmationDialogState();
}

class _SuperAdminGrantConfirmationDialogState
    extends State<_SuperAdminGrantConfirmationDialog> {
  bool _acknowledged = false;
  String _typedValue = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final matches =
        _typedValue == widget.targetUser.phone ||
        _typedValue == widget.targetUser.username;
    return AlertDialog(
      title: Text(l10n.confirmSuperAdminGrantTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.confirmSuperAdminGrantBody),
          if (_acknowledged) ...[
            const SizedBox(height: AppSpacing.lg),
            TextField(
              decoration: InputDecoration(
                labelText: l10n.confirmSuperAdminGrantTypedMatchLabel,
              ),
              onChanged: (value) => setState(() => _typedValue = value),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        if (!_acknowledged)
          AppButton(
            label: l10n.confirmSuperAdminGrantAckButton,
            onPressed: () => setState(() => _acknowledged = true),
          )
        else
          AppButton(
            label: l10n.confirmSuperAdminGrantConfirmButton,
            onPressed: matches
                ? () => Navigator.of(context).pop(_typedValue)
                : null,
          ),
      ],
    );
  }
}
