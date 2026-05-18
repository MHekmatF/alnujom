import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class DerivedBadge extends StatelessWidget {
  const DerivedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Chip(
      label: Text(
        l10n.derivedBadgeLabel,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
