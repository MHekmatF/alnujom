// lib/features/crm/domain/entities/crm_timeline_event.dart
//
// Phase 029 — CRM domain entity: one event in a lead's merged activity
// timeline. Server events (inquiry / message / viewing_*) come from the
// crm_lead_timeline RPC; notes are merged client-side as a [CrmTimelineKind.note].

enum CrmTimelineKind {
  inquiry,
  message,
  viewingRequested,
  viewingConfirmed,
  viewingDeclined,
  viewingCancelled,
  note;

  /// Maps the RPC's `event_kind` string to the enum. Notes never come from the
  /// RPC (they are merged client-side), so 'note' is handled here for symmetry.
  static CrmTimelineKind fromWire(String raw) => switch (raw) {
    'inquiry' => CrmTimelineKind.inquiry,
    'message' => CrmTimelineKind.message,
    'viewing_requested' => CrmTimelineKind.viewingRequested,
    'viewing_confirmed' => CrmTimelineKind.viewingConfirmed,
    'viewing_declined' => CrmTimelineKind.viewingDeclined,
    'viewing_cancelled' => CrmTimelineKind.viewingCancelled,
    'note' => CrmTimelineKind.note,
    _ => CrmTimelineKind.message,
  };
}

class CrmTimelineEvent {
  const CrmTimelineEvent({
    required this.kind,
    required this.occurredAt,
    this.listingTitle,
    this.snippet,
    this.refId,
  });

  final CrmTimelineKind kind;
  final DateTime occurredAt;
  final String? listingTitle;
  final String? snippet;
  final String? refId;
}
