// Phase 20 (spec/020-admin-dashboard) — T022
// AuditLogEntryDto: maps a public.audit_logs row onto the domain
// AuditLogEntry entity. Only the data layer imports this file
// (Constitution IX). before_state / after_state are JSONB → Map.
import '../../domain/entities/audit_log_entry.dart';

class AuditLogEntryDto {
  const AuditLogEntryDto({
    required this.id,
    this.actorUserId,
    required this.action,
    required this.targetType,
    this.targetId,
    this.beforeState,
    this.afterState,
    required this.createdAt,
  });

  final String id;
  final String? actorUserId;
  final String action;
  final String targetType;
  final String? targetId;
  final Map<String, dynamic>? beforeState;
  final Map<String, dynamic>? afterState;
  final String createdAt;

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  factory AuditLogEntryDto.fromJson(Map<String, dynamic> json) {
    return AuditLogEntryDto(
      id: json['id'] as String,
      actorUserId: json['actor_user_id'] as String?,
      action: json['action'] as String? ?? '',
      targetType: json['target_type'] as String? ?? '',
      targetId: json['target_id'] as String?,
      beforeState: _asMap(json['before_state']),
      afterState: _asMap(json['after_state']),
      createdAt: json['created_at'] as String,
    );
  }

  AuditLogEntry toEntity() {
    return AuditLogEntry(
      id: id,
      actorUserId: actorUserId,
      action: action,
      targetType: targetType,
      targetId: targetId,
      beforeState: beforeState,
      afterState: afterState,
      createdAt: DateTime.parse(createdAt),
    );
  }
}
