import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class HiddenBadge extends StatelessWidget {
  const HiddenBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Chip(
      label: Text(l10n.hiddenBadge, style: Theme.of(context).textTheme.labelSmall),
      backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
