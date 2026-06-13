part of 'lead_detail_cubit.dart';

enum LeadDetailStatus { loading, ready, error }

/// A unified timeline row: either a server activity event or a CRM note.
class LeadActivityRow extends Equatable {
  const LeadActivityRow.event(CrmTimelineEvent this.event) : note = null;
  const LeadActivityRow.note(CrmNote this.note) : event = null;

  final CrmTimelineEvent? event;
  final CrmNote? note;

  bool get isNote => note != null;

  DateTime get occurredAt => note?.createdAt ?? event!.occurredAt;

  @override
  List<Object?> get props => [event?.refId, event?.occurredAt, note?.id];
}

class LeadDetailState extends Equatable {
  const LeadDetailState({
    required this.lead,
    this.status = LeadDetailStatus.loading,
    this.activity = const [],
    this.reminders = const [],
    this.contactPhone,
    this.conversationId,
  });

  final LeadDetailStatus status;
  final CrmLead lead;

  /// Notes + server timeline events, merged + sorted newest-first.
  final List<LeadActivityRow> activity;

  final List<CrmReminder> reminders;

  /// The revealed inquirer phone (from the source inquiry), when available.
  final String? contactPhone;

  /// A resolved conversation id for the in-app Chat action (lazily filled).
  final String? conversationId;

  LeadDetailState copyWith({
    LeadDetailStatus? status,
    CrmLead? lead,
    List<LeadActivityRow>? activity,
    List<CrmReminder>? reminders,
    String? contactPhone,
    String? conversationId,
  }) => LeadDetailState(
    status: status ?? this.status,
    lead: lead ?? this.lead,
    activity: activity ?? this.activity,
    reminders: reminders ?? this.reminders,
    contactPhone: contactPhone ?? this.contactPhone,
    conversationId: conversationId ?? this.conversationId,
  );

  @override
  List<Object?> get props => [
    status,
    lead,
    activity,
    reminders,
    contactPhone,
    conversationId,
  ];
}
