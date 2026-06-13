// lib/features/crm/domain/entities/crm_note.dart
//
// Phase 029 — CRM domain entity: a private note on a lead.

class CrmNote {
  const CrmNote({
    required this.id,
    required this.leadId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String leadId;
  final String body;
  final DateTime createdAt;
}
