// lib/features/crm/data/dtos/crm_reminder_dto.dart
//
// Phase 029 — DTO mirroring a public.crm_reminders row.

import '../../domain/entities/crm_reminder.dart';

class CrmReminderDto {
  const CrmReminderDto({
    required this.id,
    required this.leadId,
    required this.title,
    required this.dueAt,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String leadId;
  final String title;
  final DateTime dueAt;
  final DateTime createdAt;
  final DateTime? completedAt;

  factory CrmReminderDto.fromJson(Map<String, dynamic> json) {
    final completed = json['completed_at'] as String?;
    return CrmReminderDto(
      id: json['id'] as String,
      leadId: json['lead_id'] as String,
      title: json['title'] as String? ?? '',
      dueAt: DateTime.parse(json['due_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: completed == null ? null : DateTime.parse(completed),
    );
  }

  CrmReminder toEntity() => CrmReminder(
    id: id,
    leadId: leadId,
    title: title,
    dueAt: dueAt.toLocal(),
    createdAt: createdAt,
    completedAt: completedAt?.toLocal(),
  );
}
