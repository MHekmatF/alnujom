// Phase 21 (spec/021-ads-banners) — T024
// AdStatusChip: renders an AdStatus badge via the shared DC "Blue Crown"
// DcStatusChip so ad statuses read the same as listing/viewing/report statuses.
// No inline hex / font-size / hardcoded padding (design-tokens linter gate).
// Constitution IX: zero supabase_flutter imports.
import 'package:flutter/material.dart';

import '../../../../../core/widgets/ds/dc_status_chip.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/ad_status.dart';

/// A small chip that reflects the derived [AdStatus] of an [Ad].
///
/// Delegates to the shared [DcStatusChip]; the label stays localized via
/// [AppLocalizations].
class AdStatusChip extends StatelessWidget {
  const AdStatusChip(this.status, {super.key});

  final AdStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final (label, tone) = switch (status) {
      AdStatus.active => (l10n.adStatusActive, DcStatusTone.green),
      AdStatus.scheduled => (l10n.adStatusScheduled, DcStatusTone.neutral),
      AdStatus.expired => (l10n.adStatusExpired, DcStatusTone.red),
      AdStatus.inactive => (l10n.adStatusInactive, DcStatusTone.neutral),
      AdStatus.archived => (l10n.adStatusArchived, DcStatusTone.neutral),
    };

    return DcStatusChip(label: label, tone: tone);
  }
}
