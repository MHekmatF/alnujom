import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class RequiredFieldChip extends StatelessWidget {
  const RequiredFieldChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        l10n.requiredFieldChipLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
