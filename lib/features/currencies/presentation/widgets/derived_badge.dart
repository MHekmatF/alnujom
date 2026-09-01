import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/widgets/ds/dc_status_chip.dart';
import '../../../../l10n/app_localizations.dart';

/// "Derived rate" marker — a neutral DS status chip (batch-2 restyle: was a
/// bare Material [Chip] on `tertiaryContainer`).
class DerivedBadge extends StatelessWidget {
  const DerivedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcStatusChip(
      label: l10n.derivedBadgeLabel,
      tone: DcStatusTone.neutral,
      icon: LucideIcons.git_branch,
    );
  }
}
