// lib/features/crm/domain/entities/crm_reminder.dart
//
// Phase 029 — CRM domain entity: a follow-up reminder on a lead, surfaced as a
// device-local notification (no server scheduler).

class CrmReminder {
  const CrmReminder({
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

  bool get isCompleted => completedAt != null;

  /// Overdue or due now (and not yet completed) — drives the "due today" banner.
  bool isDueOrOverdue(DateTime now) =>
      completedAt == null && !dueAt.isAfter(now);

  /// A future, still-open reminder — these get (re)scheduled locally.
  bool isOpenFuture(DateTime now) =>
      completedAt == null && dueAt.isAfter(now);

  CrmReminder copyWith({DateTime? completedAt, bool clearCompleted = false}) =>
      CrmReminder(
        id: id,
        leadId: leadId,
        title: title,
        dueAt: dueAt,
        createdAt: createdAt,
        completedAt: clearCompleted ? null : (completedAt ?? this.completedAt),
      );
}
