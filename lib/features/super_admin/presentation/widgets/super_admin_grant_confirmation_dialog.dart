import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
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

/// Two-step destructive confirmation (acknowledge → typed-match) — kept as a
/// hand-rolled [AlertDialog] because the primary action swaps label/behavior
/// and stays disabled until the typed value matches, which [AppDialog]'s
/// fixed action pair cannot express. Visuals mirror the AppDialog idiom
/// (tinted warning glyph, token type, AppButton actions).
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
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final matches =
        _typedValue == widget.targetUser.phone ||
        _typedValue == widget.targetUser.username;
    return AlertDialog(
      icon: Container(
        width: AppSpacing.xxxl,
        height: AppSpacing.xxxl,
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          LucideIcons.triangle_alert,
          color: colors.warning,
          size: AppSpacing.xl,
        ),
      ),
      title: Text(l10n.confirmSuperAdminGrantTitle, style: styles.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.confirmSuperAdminGrantBody, style: styles.bodyMedium),
          if (_acknowledged) ...[
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l10n.confirmSuperAdminGrantTypedMatchLabel,
              onChanged: (value) => setState(() => _typedValue = value),
            ),
          ],
        ],
      ),
      actions: [
        AppButton(
          label: l10n.actionCancel,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
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
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}
