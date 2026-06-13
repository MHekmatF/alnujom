// lib/features/crm/presentation/widgets/crm_stage_styles.dart
//
// Phase 029 (F1) — shared, token-clean stage label + color resolution for the
// CRM pipeline (used by the filter chips, lead cards, and the stage picker).

import 'package:flutter/widgets.dart';

import '../../../../core/theme/colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/crm_stage.dart';

String crmStageLabel(CrmStage stage, AppLocalizations l10n) => switch (stage) {
  CrmStage.newLead => l10n.crmStageNew,
  CrmStage.contacted => l10n.crmStageContacted,
  CrmStage.viewing => l10n.crmStageViewing,
  CrmStage.negotiation => l10n.crmStageNegotiation,
  CrmStage.won => l10n.crmStageWon,
  CrmStage.lost => l10n.crmStageLost,
};

Color crmStageColor(CrmStage stage, AppColors colors) => switch (stage) {
  CrmStage.newLead => colors.accent,
  CrmStage.contacted => colors.primary,
  CrmStage.viewing => colors.warning,
  CrmStage.negotiation => colors.tertiary,
  CrmStage.won => colors.success,
  CrmStage.lost => colors.error,
};
