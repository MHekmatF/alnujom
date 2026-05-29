// Phase 18 (spec/018-reports-moderation) — T032
// ModerationAction: the admin-readable log entity for one resolved report.
// Each row in public.moderation_actions surfaces here (data-model §2.5).
// Zero Supabase imports (Constitution IX).
import 'package:equatable/equatable.dart';

import 'moderation_action_type.dart';

class ModerationAction extends Equatable {
  const ModerationAction({
    required this.id,
    required this.targetId,
    required this.action,
    required this.performedBy,
    required this.performedAt,
    this.reportId,
    this.reason,
    this.beforeState,
    this.afterState,
  });

  final String id;

  /// The listing uuid the action was applied to (target_id column).
  final String targetId;

  /// Which of the four moderation actions was taken.
  final ModerationActionType action;

  /// The admin user (auth.users.id) who performed this action, or null if
  /// the account has been deleted (ON DELETE SET NULL).
  final String? performedBy;

  final DateTime performedAt;

  /// The triggering report id, or null if the record was orphaned by a
  /// report deletion (ON DELETE SET NULL).
  final String? reportId;

  /// Optional note / auto-resolve reason string.
  final String? reason;

  /// Listing state snapshot before the action ({status, title}).
  final Map<String, dynamic>? beforeState;

  /// Listing state snapshot after the action ({status, title}).
  final Map<String, dynamic>? afterState;

  @override
  List<Object?> get props => [id, targetId, action, performedAt, reportId];
}
