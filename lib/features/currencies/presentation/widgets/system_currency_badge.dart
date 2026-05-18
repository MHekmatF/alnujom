import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class SystemCurrencyBadge extends StatelessWidget {
  const SystemCurrencyBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Chip(
      label: Text(
        l10n.systemCurrencyBadge,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
