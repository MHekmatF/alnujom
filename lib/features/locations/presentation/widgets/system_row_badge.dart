import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/widgets/ds/dc_status_chip.dart';
import '../../../../l10n/app_localizations.dart';

/// "System row" marker — an outlined DS status chip (batch-2 restyle: was a
/// bare Material [Chip] on `secondaryContainer`). Matches SystemCurrencyBadge.
class SystemRowBadge extends StatelessWidget {
  const SystemRowBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcStatusChip(
      label: l10n.systemBadge,
      tone: DcStatusTone.outline,
      icon: LucideIcons.lock,
    );
  }
}
