// lib/features/crm/data/datasources/supabase_crm_datasource.dart
//
// Phase 029 — SOLE importer of `package:supabase_flutter` under
// `lib/features/crm/` (Constitution IX). All Supabase I/O for the CRM feature:
//   - direct PostgREST CRUD on crm_leads / crm_notes / crm_reminders (RLS-gated)
//   - crm_lead_timeline RPC (merged activity feed)
//   - crm_upsert_lead_from_{inquiry,conversation,viewing} RPCs (contact resolved
//     server-side; the client never sees the counterpart's user id)
//
// Table/RPC names are string-keyed so the project compiles without the DB
// applied (mirrors the chat/viewings datasources).

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/crm_lead_dto.dart';
import '../dtos/crm_note_dto.dart';
import '../dtos/crm_reminder_dto.dart';

@injectable
class SupabaseCrmDatasource {
  SupabaseCrmDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// The id of the signed-in user, or `null` when signed out. Used by the
  /// mapping layer to recognise self-anchored manual leads.
  String? get currentUserId => _client.auth.currentUser?.id;

  static const String _leadColumns =
      'id, contact_user_id, source_inquiry_id, listing_id, '
      'display_name, stage, created_at, updated_at';

  // ── Leads ──────────────────────────────────────────────────────────────────

  Future<List<CrmLeadDto>> loadLeads({String? stage}) async {
    var query = _client.from('crm_leads').select(_leadColumns);
    if (stage != null) {
      query = query.eq('stage', stage);
    }
    final rows = await query.order('updated_at', ascending: false);
    return (rows as List<dynamic>)
        .map((r) => CrmLeadDto.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Inserts a manual lead anchored to the publisher themselves (the DB defaults
  /// publisher_user_id to auth.uid(); we set contact_user_id to the same id so
  /// the identity check passes). Returns the new lead id.
  Future<String> createManualLead({required String displayName}) async {
    final uid = currentUserId;
    final row = await _client
        .from('crm_leads')
        .insert({'display_name': displayName, 'contact_user_id': uid})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> upsertLeadFromInquiry({
    required String inquiryId,
    String? displayName,
  }) async {
    final result = await _client.rpc(
      'crm_upsert_lead_from_inquiry',
      params: {'p_inquiry_id': inquiryId, 'p_display_name': displayName},
    );
    return result as String;
  }

  Future<String> upsertLeadFromConversation({
    required String conversationId,
    String? displayName,
  }) async {
    final result = await _client.rpc(
      'crm_upsert_lead_from_conversation',
      params: {
        'p_conversation_id': conversationId,
        'p_display_name': displayName,
      },
    );
    return result as String;
  }

  Future<String> upsertLeadFromViewing({
    required String viewingId,
    String? displayName,
  }) async {
    final result = await _client.rpc(
      'crm_upsert_lead_from_viewing',
      params: {'p_viewing_id': viewingId, 'p_display_name': displayName},
    );
    return result as String;
  }

  Future<void> updateStage({
    required String leadId,
    required String stage,
  }) async {
    final rows = await _client
        .from('crm_leads')
        .update({'stage': stage})
        .eq('id', leadId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw StateError('crm_lead_update_blocked: no row updated for $leadId');
    }
  }

  Future<void> deleteLead(String leadId) async {
    await _client.from('crm_leads').delete().eq('id', leadId);
  }

  // ── Timeline ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadTimeline(String leadId) async {
    final rows = await _client.rpc(
      'crm_lead_timeline',
      params: {'p_lead_id': leadId, 'p_limit': 100},
    );
    return (rows as List<dynamic>)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  // ── Notes ──────────────────────────────────────────────────────────────────

  Future<List<CrmNoteDto>> loadNotes(String leadId) async {
    final rows = await _client
        .from('crm_notes')
        .select('id, lead_id, body, created_at')
        .eq('lead_id', leadId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((r) => CrmNoteDto.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<CrmNoteDto> addNote({
    required String leadId,
    required String body,
  }) async {
    final row = await _client
        .from('crm_notes')
        .insert({'lead_id': leadId, 'body': body})
        .select('id, lead_id, body, created_at')
        .single();
    return CrmNoteDto.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteNote(String noteId) async {
    await _client.from('crm_notes').delete().eq('id', noteId);
  }

  // ── Reminders ──────────────────────────────────────────────────────────────

  Future<List<CrmReminderDto>> loadReminders(String leadId) async {
    final rows = await _client
        .from('crm_reminders')
        .select('id, lead_id, title, due_at, completed_at, created_at')
        .eq('lead_id', leadId)
        .order('due_at', ascending: true);
    return (rows as List<dynamic>)
        .map(
          (r) => CrmReminderDto.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  Future<List<CrmReminderDto>> loadOpenReminders() async {
    final rows = await _client
        .from('crm_reminders')
        .select('id, lead_id, title, due_at, completed_at, created_at')
        .isFilter('completed_at', null)
        .order('due_at', ascending: true);
    return (rows as List<dynamic>)
        .map(
          (r) => CrmReminderDto.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  Future<CrmReminderDto> addReminder({
    required String leadId,
    required String title,
    required DateTime dueAtUtc,
  }) async {
    final row = await _client
        .from('crm_reminders')
        .insert({
          'lead_id': leadId,
          'title': title,
          'due_at': dueAtUtc.toUtc().toIso8601String(),
        })
        .select('id, lead_id, title, due_at, completed_at, created_at')
        .single();
    return CrmReminderDto.fromJson(Map<String, dynamic>.from(row));
  }

  Future<CrmReminderDto> setReminderCompleted({
    required String reminderId,
    required bool completed,
  }) async {
    final row = await _client
        .from('crm_reminders')
        .update({
          'completed_at': completed
              ? DateTime.now().toUtc().toIso8601String()
              : null,
        })
        .eq('id', reminderId)
        .select('id, lead_id, title, due_at, completed_at, created_at')
        .single();
    return CrmReminderDto.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteReminder(String reminderId) async {
    await _client.from('crm_reminders').delete().eq('id', reminderId);
  }
}
