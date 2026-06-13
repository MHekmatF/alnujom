part of 'crm_leads_cubit.dart';

enum CrmLeadsStatus { initial, loading, ready, error }

class CrmLeadsState extends Equatable {
  const CrmLeadsState({
    this.status = CrmLeadsStatus.initial,
    this.leads = const [],
    this.dueReminders = const [],
    this.stageFilter,
    this.permissionDenied = false,
  });

  final CrmLeadsStatus status;
  final List<CrmLead> leads;

  /// Overdue/today reminders across all leads — drives the "due today" banner.
  final List<CrmReminder> dueReminders;

  /// The active stage filter; null = "All".
  final CrmStage? stageFilter;

  /// True when the OS notification permission was denied (banner fallback hint).
  final bool permissionDenied;

  CrmLeadsState copyWith({
    CrmLeadsStatus? status,
    List<CrmLead>? leads,
    List<CrmReminder>? dueReminders,
    CrmStage? stageFilter,
    bool clearStageFilter = false,
    bool? permissionDenied,
  }) => CrmLeadsState(
    status: status ?? this.status,
    leads: leads ?? this.leads,
    dueReminders: dueReminders ?? this.dueReminders,
    stageFilter: clearStageFilter ? null : (stageFilter ?? this.stageFilter),
    permissionDenied: permissionDenied ?? this.permissionDenied,
  );

  @override
  List<Object?> get props => [
    status,
    leads,
    dueReminders,
    stageFilter,
    permissionDenied,
  ];
}
