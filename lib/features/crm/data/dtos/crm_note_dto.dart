// lib/features/crm/data/dtos/crm_note_dto.dart
//
// Phase 029 — DTO mirroring a public.crm_notes row.

import '../../domain/entities/crm_note.dart';

class CrmNoteDto {
  const CrmNoteDto({
    required this.id,
    required this.leadId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String leadId;
  final String body;
  final DateTime createdAt;

  factory CrmNoteDto.fromJson(Map<String, dynamic> json) => CrmNoteDto(
    id: json['id'] as String,
    leadId: json['lead_id'] as String,
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  CrmNote toEntity() => CrmNote(
    id: id,
    leadId: leadId,
    body: body,
    createdAt: createdAt,
  );
}
