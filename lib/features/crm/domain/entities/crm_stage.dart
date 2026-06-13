// lib/features/crm/domain/entities/crm_stage.dart
//
// Phase 029 — CRM lead pipeline stage. Six ordered stages from first contact
// to a won/lost outcome. The wire value is the DB CHECK string.

enum CrmStage {
  newLead,
  contacted,
  viewing,
  negotiation,
  won,
  lost;

  /// The DB / wire string (matches the crm_leads.stage CHECK constraint).
  String get wire => switch (this) {
    CrmStage.newLead => 'new',
    CrmStage.contacted => 'contacted',
    CrmStage.viewing => 'viewing',
    CrmStage.negotiation => 'negotiation',
    CrmStage.won => 'won',
    CrmStage.lost => 'lost',
  };

  /// Parses a raw DB string. Unknown values fall back to [newLead] (defensive —
  /// the DB CHECK constrains it to the six values).
  static CrmStage fromWire(String raw) => switch (raw) {
    'contacted' => CrmStage.contacted,
    'viewing' => CrmStage.viewing,
    'negotiation' => CrmStage.negotiation,
    'won' => CrmStage.won,
    'lost' => CrmStage.lost,
    _ => CrmStage.newLead,
  };

  /// The pipeline stages in display order (used by the filter chip row).
  static const List<CrmStage> ordered = [
    CrmStage.newLead,
    CrmStage.contacted,
    CrmStage.viewing,
    CrmStage.negotiation,
    CrmStage.won,
    CrmStage.lost,
  ];
}
