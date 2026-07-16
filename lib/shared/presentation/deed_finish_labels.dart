import '../../l10n/app_localizations.dart';

/// Phase 035 Stage 3 — canonical value lists + localized labels for the
/// Syria-native listing attributes: deed type (الطابو) and finish level
/// (الكسوة). Shared by the listing card, detail facts, search filters, and the
/// add-listing form so the enum values stay in one place.

const List<String> kDeedTypes = <String>[
  'green',
  'red',
  'temporary',
  'agricultural',
  'court_ruling',
];

const List<String> kFinishLevels = <String>[
  'on_bone',
  'normal',
  'deluxe',
  'super_deluxe',
];

String deedTypeLabel(AppLocalizations l10n, String? key) => switch (key) {
  'green' => l10n.deed_green,
  'red' => l10n.deed_red,
  'temporary' => l10n.deed_temporary,
  'agricultural' => l10n.deed_agricultural,
  'court_ruling' => l10n.deed_court_ruling,
  _ => '',
};

String finishLevelLabel(AppLocalizations l10n, String? key) => switch (key) {
  'on_bone' => l10n.finish_on_bone,
  'normal' => l10n.finish_normal,
  'deluxe' => l10n.finish_deluxe,
  'super_deluxe' => l10n.finish_super_deluxe,
  _ => '',
};
