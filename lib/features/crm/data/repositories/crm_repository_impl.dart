// lib/features/crm/data/repositories/crm_repository_impl.dart
//
// Phase 029 — concrete [CrmRepository] delegating to [SupabaseCrmDatasource].
// Principle IX: MUST NOT import supabase_flutter (the datasource is the sole
// importer). All methods map exceptions to typed [Failure]s.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/crm_lead.dart';
import '../../domain/entities/crm_note.dart';
import '../../domain/entities/crm_reminder.dart';
import '../../domain/entities/crm_stage.dart';
import '../../domain/entities/crm_timeline_event.dart';
import '../../domain/repositories/crm_repository.dart';
import '../datasources/supabase_crm_datasource.dart';

@LazySingleton(as: CrmRepository)
class CrmRepositoryImpl implements CrmRepository {
  CrmRepositoryImpl(this._datasource);

  final SupabaseCrmDatasource _datasource;

  Future<Result<T>> _guard<T>(
    String op,
    Future<T> Function() body,
  ) async {
    try {
      return Success(await body());
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('$op failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<CrmLead>>> loadLeads({CrmStage? stage}) => _guard(
    'loadLeads',
    () async {
      final uid = _datasource.currentUserId ?? '';
      final dtos = await _datasource.loadLeads(stage: stage?.wire);
      return dtos.map((d) => d.toEntity(uid)).toList();
    },
  );

  @override
  Future<Result<String>> createManualLead({required String displayName}) =>
      _guard(
        'createManualLead',
        () => _datasource.createManualLead(displayName: displayName),
      );

  @override
  Future<Result<String>> upsertLeadFromInquiry({
    required String inquiryId,
    String? displayName,
  }) => _guard(
    'upsertLeadFromInquiry',
    () => _datasource.upsertLeadFromInquiry(
      inquiryId: inquiryId,
      displayName: displayName,
    ),
  );

  @override
  Future<Result<String>> upsertLeadFromConversation({
    required String conversationId,
    String? displayName,
  }) => _guard(
    'upsertLeadFromConversation',
    () => _datasource.upsertLeadFromConversation(
      conversationId: conversationId,
      displayName: displayName,
    ),
  );

  @override
  Future<Result<String>> upsertLeadFromViewing({
    required String viewingId,
    String? displayName,
  }) => _guard(
    'upsertLeadFromViewing',
    () => _datasource.upsertLeadFromViewing(
      viewingId: viewingId,
      displayName: displayName,
    ),
  );

  @override
  Future<Result<void>> updateStage({
    required String leadId,
    required CrmStage stage,
  }) => _guard(
    'updateStage',
    () => _datasource.updateStage(leadId: leadId, stage: stage.wire),
  );

  @override
  Future<Result<void>> deleteLead(String leadId) =>
      _guard('deleteLead', () => _datasource.deleteLead(leadId));

  @override
  Future<Result<List<CrmTimelineEvent>>> loadTimeline(String leadId) => _guard(
    'loadTimeline',
    () async {
      final rows = await _datasource.loadTimeline(leadId);
      return rows.map((r) {
        final occurredRaw = r['occurred_at'] as String;
        return CrmTimelineEvent(
          kind: CrmTimelineKind.fromWire(r['event_kind'] as String),
          occurredAt: DateTime.parse(occurredRaw).toLocal(),
          listingTitle: r['listing_title'] as String?,
          snippet: r['snippet'] as String?,
          refId: r['ref_id'] as String?,
        );
      }).toList();
    },
  );

  @override
  Future<Result<List<CrmNote>>> loadNotes(String leadId) => _guard(
    'loadNotes',
    () async {
      final dtos = await _datasource.loadNotes(leadId);
      return dtos.map((d) => d.toEntity()).toList();
    },
  );

  @override
  Future<Result<CrmNote>> addNote({
    required String leadId,
    required String body,
  }) => _guard(
    'addNote',
    () async {
      final dto = await _datasource.addNote(leadId: leadId, body: body);
      return dto.toEntity();
    },
  );

  @override
  Future<Result<void>> deleteNote(String noteId) =>
      _guard('deleteNote', () => _datasource.deleteNote(noteId));

  @override
  Future<Result<List<CrmReminder>>> loadReminders(String leadId) => _guard(
    'loadReminders',
    () async {
      final dtos = await _datasource.loadReminders(leadId);
      return dtos.map((d) => d.toEntity()).toList();
    },
  );

  @override
  Future<Result<List<CrmReminder>>> loadOpenReminders() => _guard(
    'loadOpenReminders',
    () async {
      final dtos = await _datasource.loadOpenReminders();
      return dtos.map((d) => d.toEntity()).toList();
    },
  );

  @override
  Future<Result<CrmReminder>> addReminder({
    required String leadId,
    required String title,
    required DateTime dueAt,
  }) => _guard(
    'addReminder',
    () async {
      final dto = await _datasource.addReminder(
        leadId: leadId,
        title: title,
        dueAtUtc: dueAt,
      );
      return dto.toEntity();
    },
  );

  @override
  Future<Result<CrmReminder>> setReminderCompleted({
    required String reminderId,
    required bool completed,
  }) => _guard(
    'setReminderCompleted',
    () async {
      final dto = await _datasource.setReminderCompleted(
        reminderId: reminderId,
        completed: completed,
      );
      return dto.toEntity();
    },
  );

  @override
  Future<Result<void>> deleteReminder(String reminderId) =>
      _guard('deleteReminder', () => _datasource.deleteReminder(reminderId));
}
