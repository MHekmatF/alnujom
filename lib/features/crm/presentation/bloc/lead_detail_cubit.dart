// lib/features/crm/presentation/bloc/lead_detail_cubit.dart
//
// Phase 029 (F1) — drives the lead detail page: stage (optimistic), the merged
// activity timeline (server events + notes), notes add/delete, reminders
// add/complete/delete (with local-notification side effects), the revealed
// inquirer phone (reused from the existing inquiry-detail decrypt path), and
// lazy in-app conversation resolution for the Chat action.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/notifications/local_reminder_scheduler.dart';
import '../../../chat/domain/usecases/get_or_create_conversation.dart';
import '../../../inquiries/domain/entities/inquiry.dart';
import '../../../inquiries/domain/usecases/load_inquiry_detail.dart';
import '../../domain/entities/crm_lead.dart';
import '../../domain/entities/crm_note.dart';
import '../../domain/entities/crm_reminder.dart';
import '../../domain/entities/crm_stage.dart';
import '../../domain/entities/crm_timeline_event.dart';
import '../../domain/repositories/crm_repository.dart';

part 'lead_detail_state.dart';

@injectable
class LeadDetailCubit extends Cubit<LeadDetailState> {
  LeadDetailCubit(
    this._repository,
    this._scheduler,
    this._loadInquiryDetail,
    this._getOrCreateConversation,
  ) : super(LeadDetailState(lead: _placeholderLead));

  final CrmRepository _repository;
  final LocalReminderScheduler _scheduler;
  final LoadInquiryDetail _loadInquiryDetail;
  final GetOrCreateConversation _getOrCreateConversation;

  // A sentinel lead so the state is never nullable before [open] resolves.
  static final CrmLead _placeholderLead = CrmLead(
    id: '',
    displayName: '',
    stage: CrmStage.newLead,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  Future<void> open(CrmLead lead) async {
    emit(LeadDetailState(lead: lead, status: LeadDetailStatus.loading));
    await _reload(lead);

    // Best-effort: reveal the inquirer phone from the source inquiry (reuses
    // the inquiry-detail decrypt path; the view-side authorization is enforced
    // server-side by decrypt_inquirer_phone).
    final inquiryId = lead.sourceInquiryId;
    if (inquiryId != null) {
      final result = await _loadInquiryDetail(inquiryId);
      if (!isClosed) {
        if (result case Success<Inquiry>(:final value)) {
          if (value.decryptedPhone != null) {
            emit(state.copyWith(contactPhone: value.decryptedPhone));
          }
        }
      }
    }
  }

  Future<void> _reload(CrmLead lead) async {
    final timeline = await _repository.loadTimeline(lead.id);
    final notes = await _repository.loadNotes(lead.id);
    final reminders = await _repository.loadReminders(lead.id);
    if (isClosed) return;

    final events = switch (timeline) {
      Success<List<CrmTimelineEvent>>(:final value) => value
          .map(LeadActivityRow.event)
          .toList(),
      FailureResult<List<CrmTimelineEvent>>() => <LeadActivityRow>[],
    };
    final noteRows = switch (notes) {
      Success<List<CrmNote>>(:final value) => value
          .map(LeadActivityRow.note)
          .toList(),
      FailureResult<List<CrmNote>>() => <LeadActivityRow>[],
    };

    final merged = [...events, ...noteRows]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    final reminderList = switch (reminders) {
      Success<List<CrmReminder>>(:final value) => value,
      FailureResult<List<CrmReminder>>() => const <CrmReminder>[],
    };

    final failedAll = timeline is FailureResult &&
        notes is FailureResult &&
        reminders is FailureResult;

    emit(
      state.copyWith(
        lead: lead,
        status: failedAll ? LeadDetailStatus.error : LeadDetailStatus.ready,
        activity: merged,
        reminders: reminderList,
      ),
    );
  }

  Future<void> retry() => _reload(state.lead);

  // ── Stage ──────────────────────────────────────────────────────────────────

  Future<void> changeStage(CrmStage stage) async {
    final previous = state.lead;
    if (previous.stage == stage) return;
    // Optimistic.
    emit(state.copyWith(lead: previous.copyWith(stage: stage)));
    final result = await _repository.updateStage(
      leadId: previous.id,
      stage: stage,
    );
    if (result is FailureResult && !isClosed) {
      emit(state.copyWith(lead: previous));
    }
  }

  // ── Notes ──────────────────────────────────────────────────────────────────

  /// Adds a note. Returns true on success.
  Future<bool> addNote(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return false;
    final result = await _repository.addNote(leadId: state.lead.id, body: trimmed);
    if (result is Success<CrmNote> && !isClosed) {
      final merged = [LeadActivityRow.note(result.value), ...state.activity]
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      emit(state.copyWith(activity: merged));
      return true;
    }
    return false;
  }

  Future<bool> deleteNote(String noteId) async {
    final result = await _repository.deleteNote(noteId);
    if (result is Success<void> && !isClosed) {
      emit(
        state.copyWith(
          activity: state.activity
              .where((r) => r.note?.id != noteId)
              .toList(),
        ),
      );
      return true;
    }
    return false;
  }

  // ── Reminders ────────────────────────────────────────────────────────────────

  /// Adds a reminder + schedules a local notification. Returns true on success.
  Future<bool> addReminder({
    required String title,
    required DateTime dueAt,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;
    final result = await _repository.addReminder(
      leadId: state.lead.id,
      title: trimmed,
      dueAt: dueAt,
    );
    if (result is Success<CrmReminder> && !isClosed) {
      final reminder = result.value;
      await _scheduler.schedule(
        reminderId: reminder.id,
        title: reminder.title,
        due: reminder.dueAt,
      );
      final list = [...state.reminders, reminder]
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      emit(state.copyWith(reminders: list));
      return true;
    }
    return false;
  }

  /// Toggles completion: sets/clears completed_at and (un)schedules the local
  /// notification.
  Future<void> toggleReminderCompleted(CrmReminder reminder) async {
    final markComplete = !reminder.isCompleted;
    final result = await _repository.setReminderCompleted(
      reminderId: reminder.id,
      completed: markComplete,
    );
    if (result is Success<CrmReminder> && !isClosed) {
      final updated = result.value;
      if (markComplete) {
        await _scheduler.cancel(reminder.id);
      } else {
        await _scheduler.schedule(
          reminderId: updated.id,
          title: updated.title,
          due: updated.dueAt,
        );
      }
      final list = state.reminders
          .map((r) => r.id == updated.id ? updated : r)
          .toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      emit(state.copyWith(reminders: list));
    }
  }

  Future<bool> deleteReminder(CrmReminder reminder) async {
    final result = await _repository.deleteReminder(reminder.id);
    if (result is Success<void> && !isClosed) {
      await _scheduler.cancel(reminder.id);
      emit(
        state.copyWith(
          reminders: state.reminders
              .where((r) => r.id != reminder.id)
              .toList(),
        ),
      );
      return true;
    }
    return false;
  }

  // ── In-app chat ──────────────────────────────────────────────────────────────

  /// Resolves (creating if needed) the conversation for this lead's listing so
  /// the page can push the chat thread. Returns the conversation id, or null on
  /// failure (no listing / RPC error).
  Future<String?> resolveConversationId() async {
    if (state.conversationId != null) return state.conversationId;
    final listingId = state.lead.listingId;
    if (listingId == null) return null;
    final result = await _getOrCreateConversation(listingId);
    if (result is Success<String>) {
      if (!isClosed) emit(state.copyWith(conversationId: result.value));
      return result.value;
    }
    return null;
  }
}
