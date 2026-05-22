import 'package:flutter/material.dart';

import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

class RejectionReasonBlock extends StatelessWidget {
  const RejectionReasonBlock({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.rejectionReasonLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reason,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
