import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class SystemRowBadge extends StatelessWidget {
  const SystemRowBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Chip(
      label: Text(l10n.systemBadge, style: Theme.of(context).textTheme.labelSmall),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
