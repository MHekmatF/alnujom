// Phase 20 (spec/020-admin-dashboard) — T021
// AuditLogEntry: pure-Dart domain entity for one public.audit_logs row
// (data-model §2.3). No package:supabase_flutter import (Constitution IX).
//
// Note: audit_logs.id is UUID (Phase 4 20260506120004:
//   id UUID PRIMARY KEY DEFAULT gen_random_uuid()), not an int — the
// entity uses String. actor_user_id is nullable (ON DELETE SET NULL).
import 'package:equatable/equatable.dart';

class AuditLogEntry extends Equatable {
  const AuditLogEntry({
    required this.id,
    this.actorUserId,
    required this.action,
    required this.targetType,
    this.targetId,
    this.beforeState,
    this.afterState,
    required this.createdAt,
  });

  /// UUID primary key of the audit row.
  final String id;

  /// The acting user (null when the actor was deleted — ON DELETE SET NULL).
  final String? actorUserId;

  /// The audited action key (e.g. 'listing.approved', 'role.assigned').
  final String action;

  /// The kind of entity acted on (e.g. 'listing', 'report', 'agency').
  final String targetType;

  /// The id of the acted-on entity (nullable).
  final String? targetId;

  /// JSONB snapshot before the change (nullable).
  final Map<String, dynamic>? beforeState;

  /// JSONB snapshot after the change (nullable).
  final Map<String, dynamic>? afterState;

  /// When the audit row was written.
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        actorUserId,
        action,
        targetType,
        targetId,
        beforeState,
        afterState,
        createdAt,
      ];
}
