// lib/features/agency/presentation/widgets/agency_status_chip.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T050).
// Canonical localized AgencyStatus pill.
// Batch-2 restyle: was a bare Material Chip driven off raw `colorScheme`
// containers; now the shared DS [DcStatusChip] so it matches every other status
// pill in the app (reports, listings, viewings, ads).
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/widgets/ds/dc_status_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/agency_status.dart';

/// A small status chip visualising an [AgencyStatus] with the DS status tones.
///
/// Tone mapping:
///   pending   → neutral (surfaceVariant)
///   approved  → green   (verifiedContainer)
///   rejected  → red     (errorContainer)
///   suspended → outline (hairline, de-emphasized)
class AgencyStatusChip extends StatelessWidget {
  const AgencyStatusChip(this.status, {super.key});

  final AgencyStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final (label, tone, icon) = switch (status) {
      AgencyStatus.pending => (
        l10n.agency_status_pending,
        DcStatusTone.neutral,
        LucideIcons.clock,
      ),
      AgencyStatus.approved => (
        l10n.agency_status_approved,
        DcStatusTone.green,
        LucideIcons.badge_check,
      ),
      AgencyStatus.rejected => (
        l10n.agency_status_rejected,
        DcStatusTone.red,
        LucideIcons.circle_x,
      ),
      AgencyStatus.suspended => (
        l10n.agency_status_suspended,
        DcStatusTone.outline,
        LucideIcons.ban,
      ),
    };

    return DcStatusChip(label: label, tone: tone, icon: icon);
  }
}
