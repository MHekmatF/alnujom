// lib/features/crm/domain/repositories/crm_repository.dart
//
// Phase 029 — CRM repository contract. The data layer is the sole importer of
// supabase_flutter (Constitution IX); this interface stays platform-free.

import '../../../../core/errors/result.dart';
import '../entities/crm_lead.dart';
import '../entities/crm_note.dart';
import '../entities/crm_reminder.dart';
import '../entities/crm_stage.dart';
import '../entities/crm_timeline_event.dart';

abstract class CrmRepository {
  /// Loads the publisher's leads, optionally filtered to a single [stage],
  /// most-recently-touched first.
  Future<Result<List<CrmLead>>> loadLeads({CrmStage? stage});

  /// Creates a manual lead (anchored to the publisher themselves so the DB
  /// identity check is satisfied). Returns the new lead id.
  Future<Result<String>> createManualLead({required String displayName});

  /// Attaches (or returns an existing) lead for an inquiry's sender. The DB
  /// resolves the contact + verifies ownership. Returns the lead id.
  Future<Result<String>> upsertLeadFromInquiry({
    required String inquiryId,
    String? displayName,
  });

  /// Attaches (or returns an existing) lead for a conversation's buyer.
  Future<Result<String>> upsertLeadFromConversation({
    required String conversationId,
    String? displayName,
  });

  /// Attaches (or returns an existing) lead for a viewing's requester.
  Future<Result<String>> upsertLeadFromViewing({
    required String viewingId,
    String? displayName,
  });

  /// Persists a stage change on a lead.
  Future<Result<void>> updateStage({
    required String leadId,
    required CrmStage stage,
  });

  /// Deletes a lead (cascades notes + reminders).
  Future<Result<void>> deleteLead(String leadId);

  /// The server-side activity timeline for a lead (inquiries/messages/viewings).
  Future<Result<List<CrmTimelineEvent>>> loadTimeline(String leadId);

  /// The notes on a lead, newest-first.
  Future<Result<List<CrmNote>>> loadNotes(String leadId);

  /// Adds a note to a lead. Returns the created note.
  Future<Result<CrmNote>> addNote({
    required String leadId,
    required String body,
  });

  /// Deletes a note.
  Future<Result<void>> deleteNote(String noteId);

  /// The reminders on a lead, soonest-due first.
  Future<Result<List<CrmReminder>>> loadReminders(String leadId);

  /// The publisher's open future reminders across ALL leads (for the launch
  /// reschedule + the "due today" banner source).
  Future<Result<List<CrmReminder>>> loadOpenReminders();

  /// Creates a reminder on a lead. Returns the created reminder.
  Future<Result<CrmReminder>> addReminder({
    required String leadId,
    required String title,
    required DateTime dueAt,
  });

  /// Toggles a reminder's completion (sets/clears completed_at). Returns the
  /// updated reminder.
  Future<Result<CrmReminder>> setReminderCompleted({
    required String reminderId,
    required bool completed,
  });

  /// Deletes a reminder.
  Future<Result<void>> deleteReminder(String reminderId);
}
