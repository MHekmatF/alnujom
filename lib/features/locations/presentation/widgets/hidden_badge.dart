import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/widgets/ds/dc_status_chip.dart';
import '../../../../l10n/app_localizations.dart';

/// "Hidden row" marker — a neutral DS status chip (batch-2 restyle: was a bare
/// Material [Chip] on a 15%-alpha outline fill, which read as a smudge in dark).
class HiddenBadge extends StatelessWidget {
  const HiddenBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcStatusChip(
      label: l10n.hiddenBadge,
      tone: DcStatusTone.neutral,
      icon: LucideIcons.eye_off,
    );
  }
}
